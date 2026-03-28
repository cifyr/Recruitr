import AVFoundation
import Foundation

// OpenAI Whisper API Response Model
struct WhisperAPIResponse: Codable {
    let text: String
}

// OpenAI Error Response (shared with OpenAIFieldExtractor)
struct WhisperErrorResponse: Codable {
    let error: WhisperError
}

struct WhisperError: Codable {
    let message: String
    let code: String?
}

private struct MultipartUploadPayload {
    let bodyFileURL: URL
    let boundary: String
    let bodySize: Int64
}

class CloudAudioTranscriber {
    static let shared = CloudAudioTranscriber()
    
    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let transcriptionModel = "whisper-1"
    private let apiUploadLimitBytes: Int64 = 25 * 1024 * 1024
    private let preferredChunkUploadBytes: Int64 = 4 * 1024 * 1024
    private let minimumChunkDuration: TimeInterval = 30
    private let maximumChunkDuration: TimeInterval = 8 * 60
    private let maxUploadAttempts = 3
    private let fileReadBufferSize = 1024 * 1024
    
    private init() {}
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsConstrainedNetworkAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        return URLSession(configuration: configuration)
    }()
    
    /// Transcribes audio file using OpenAI's transcription API.
    func transcribeAudio(url: URL, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "CloudAudioTranscriber", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key is required"])
        }
        
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let workingFileURL = try stageAudioFileLocally(from: url)
        defer {
            try? FileManager.default.removeItem(at: workingFileURL.deletingLastPathComponent())
        }
        
        let fileSize = fileSize(at: workingFileURL)
        
        if shouldChunkBeforeUpload(fileSize: fileSize) {
            return try await transcribeLargeFile(url: workingFileURL, apiKey: apiKey, fileSize: fileSize)
        }
        
        do {
            return try await transcribeSingleFile(url: workingFileURL, apiKey: apiKey)
        } catch let error as NSError where shouldFallbackToChunking(fileSize: fileSize, error: error) {
            return try await transcribeLargeFile(url: workingFileURL, apiKey: apiKey, fileSize: fileSize)
        }
    }
    
    private func shouldChunkBeforeUpload(fileSize: Int64) -> Bool {
        fileSize > preferredChunkUploadBytes
    }
    
    private func shouldFallbackToChunking(fileSize: Int64, error: NSError) -> Bool {
        guard fileSize > 0 else {
            return false
        }
        
        return shouldSplitChunkAfterFailure(error)
    }
    
    private func shouldSplitChunkAfterFailure(_ error: NSError) -> Bool {
        if error.domain == "CloudAudioTranscriber", error.code == 413 {
            return true
        }
        
        guard error.domain == "CloudAudioTranscriber",
              error.code == 7,
              let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError else {
            return false
        }
        
        return shouldRetryUpload(for: underlyingError)
    }
    
    /// Uploads a single audio file or exported chunk using a file-backed multipart body.
    private func transcribeSingleFile(url: URL, apiKey: String) async throws -> String {
        let fileExtension = normalizedFileExtension(for: url)
        let mimeType = mimeType(for: fileExtension)
        let payload = try createMultipartUploadPayload(for: url, fileExtension: fileExtension, mimeType: mimeType)
        
        defer {
            try? FileManager.default.removeItem(at: payload.bodyFileURL)
        }
        
        guard payload.bodySize <= apiUploadLimitBytes else {
            throw NSError(
                domain: "CloudAudioTranscriber",
                code: 413,
                userInfo: [NSLocalizedDescriptionKey: "Audio upload exceeds OpenAI's 25 MB request limit once multipart overhead is included."]
            )
        }
        
        let request = try makeRequest(apiKey: apiKey, boundary: payload.boundary, bodySize: payload.bodySize)
        
        do {
            let (data, response) = try await performUpload(request: request, fileURL: payload.bodyFileURL)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "CloudAudioTranscriber", code: 6, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
            
            guard httpResponse.statusCode == 200 else {
                if let errorResponse = try? JSONDecoder().decode(WhisperErrorResponse.self, from: data) {
                    throw NSError(
                        domain: "CloudAudioTranscriber",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorResponse.error.message)"]
                    )
                }
                
                throw NSError(
                    domain: "CloudAudioTranscriber",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "API request failed with status code \(httpResponse.statusCode)"]
                )
            }
            
            let whisperResponse = try JSONDecoder().decode(WhisperAPIResponse.self, from: data)
            return whisperResponse.text
        } catch let error as NSError {
            if error.domain == "CloudAudioTranscriber" {
                throw error
            }
            
            throw NSError(
                domain: "CloudAudioTranscriber",
                code: 7,
                userInfo: [
                    NSLocalizedDescriptionKey: friendlyNetworkMessage(for: error),
                    NSUnderlyingErrorKey: error
                ]
            )
        }
    }
    
    private func makeRequest(apiKey: String, boundary: String, bodySize: Int64) throws -> URLRequest {
        guard let apiURL = URL(string: baseURL) else {
            throw NSError(domain: "CloudAudioTranscriber", code: 5, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(String(bodySize), forHTTPHeaderField: "Content-Length")
        request.setValue("close", forHTTPHeaderField: "Connection")
        return request
    }
    
    private func createMultipartUploadPayload(for audioFileURL: URL, fileExtension: String, mimeType: String) throws -> MultipartUploadPayload {
        let boundary = UUID().uuidString
        let payloadURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("multipart")
        
        FileManager.default.createFile(atPath: payloadURL.path, contents: nil)
        
        let writer = try FileHandle(forWritingTo: payloadURL)
        defer {
            try? writer.close()
        }
        
        try writer.write(contentsOf: Data("--\(boundary)\r\n".utf8))
        try writer.write(contentsOf: Data("Content-Disposition: form-data; name=\"file\"; filename=\"audio.\(fileExtension)\"\r\n".utf8))
        try writer.write(contentsOf: Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        try appendFileContents(from: audioFileURL, to: writer)
        try writer.write(contentsOf: Data("\r\n".utf8))
        
        try writer.write(contentsOf: Data("--\(boundary)\r\n".utf8))
        try writer.write(contentsOf: Data("Content-Disposition: form-data; name=\"model\"\r\n\r\n".utf8))
        try writer.write(contentsOf: Data("\(transcriptionModel)\r\n".utf8))
        
        try writer.write(contentsOf: Data("--\(boundary)\r\n".utf8))
        try writer.write(contentsOf: Data("Content-Disposition: form-data; name=\"language\"\r\n\r\n".utf8))
        try writer.write(contentsOf: Data("en\r\n".utf8))
        
        try writer.write(contentsOf: Data("--\(boundary)\r\n".utf8))
        try writer.write(contentsOf: Data("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".utf8))
        try writer.write(contentsOf: Data("json\r\n".utf8))
        
        try writer.write(contentsOf: Data("--\(boundary)--\r\n".utf8))
        
        let bodySize = fileSize(at: payloadURL)
        return MultipartUploadPayload(bodyFileURL: payloadURL, boundary: boundary, bodySize: bodySize)
    }
    
    private func appendFileContents(from sourceURL: URL, to writer: FileHandle) throws {
        let reader = try FileHandle(forReadingFrom: sourceURL)
        defer {
            try? reader.close()
        }
        
        while true {
            let chunk = reader.readData(ofLength: fileReadBufferSize)
            if chunk.isEmpty {
                break
            }
            try writer.write(contentsOf: chunk)
        }
    }
    
    private func stageAudioFileLocally(from sourceURL: URL) throws -> URL {
        let stagingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileExtension = normalizedFileExtension(for: sourceURL)
        let stagedFileURL = stagingDirectory.appendingPathComponent("source").appendingPathExtension(fileExtension)
        
        try FileManager.default.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
        
        do {
            try FileManager.default.copyItem(at: sourceURL, to: stagedFileURL)
            return stagedFileURL
        } catch {
            FileManager.default.createFile(atPath: stagedFileURL.path, contents: nil)
            let writer = try FileHandle(forWritingTo: stagedFileURL)
            defer {
                try? writer.close()
            }
            
            try appendFileContents(from: sourceURL, to: writer)
            return stagedFileURL
        }
    }
    
    private func performUpload(request: URLRequest, fileURL: URL) async throws -> (Data, URLResponse) {
        var attempt = 0
        
        while true {
            do {
                return try await session.upload(for: request, fromFile: fileURL)
            } catch {
                let nsError = error as NSError
                attempt += 1
                
                guard shouldRetryUpload(for: nsError), attempt < maxUploadAttempts else {
                    throw error
                }
                
                let delaySeconds = UInt64(attempt)
                try await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
    }
    
    private func shouldRetryUpload(for error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain else {
            return false
        }
        
        switch error.code {
        case NSURLErrorNetworkConnectionLost,
             NSURLErrorTimedOut,
             NSURLErrorCannotConnectToHost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorResourceUnavailable:
            return true
        default:
            return false
        }
    }
    
    private func friendlyNetworkMessage(for error: NSError) -> String {
        guard error.domain == NSURLErrorDomain else {
            return error.localizedDescription
        }
        
        switch error.code {
        case NSURLErrorSecureConnectionFailed,
             NSURLErrorServerCertificateUntrusted,
             NSURLErrorServerCertificateHasBadDate,
             NSURLErrorServerCertificateNotYetValid:
            return "TLS/SSL connection failed. Please check your internet connection or try using Local transcription mode."
        case NSURLErrorTimedOut:
            return "Audio upload timed out. Please try again or use Local transcription mode."
        case NSURLErrorNotConnectedToInternet:
            return "No internet connection. Please use Local transcription mode."
        case NSURLErrorNetworkConnectionLost:
            return "Network connection lost during upload. The app will retry smaller chunks automatically."
        default:
            return "Network error: \(error.localizedDescription)"
        }
    }
    
    /// Transcribes a larger file by exporting and uploading smaller chunks.
    private func transcribeLargeFile(url: URL, apiKey: String, fileSize: Int64) async throws -> String {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw NSError(domain: "CloudAudioTranscriber", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unable to determine audio duration for chunked transcription."])
        }
        
        let estimatedChunkCount = max(2, Int(ceil(Double(max(fileSize, preferredChunkUploadBytes)) / Double(preferredChunkUploadBytes))))
        let idealChunkDuration = durationSeconds / Double(estimatedChunkCount)
        let targetChunkDuration = min(maximumChunkDuration, max(minimumChunkDuration, idealChunkDuration))
        
        var allTranscripts: [String] = []
        var startTime: TimeInterval = 0
        
        while startTime < durationSeconds {
            let remainingDuration = durationSeconds - startTime
            let chunkDuration = min(targetChunkDuration, remainingDuration)
            
            if chunkDuration <= 0 {
                break
            }
            
            let transcript = try await transcribeSegment(
                from: asset,
                apiKey: apiKey,
                startTime: startTime,
                duration: chunkDuration
            )
            
            allTranscripts.append(transcript)
            startTime += chunkDuration
        }
        
        return allTranscripts.joined(separator: "\n\n[--- Next Segment ---]\n\n")
    }
    
    private func transcribeSegment(from asset: AVAsset, apiKey: String, startTime: TimeInterval, duration: TimeInterval) async throws -> String {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let tempURL = tempDirectory.appendingPathComponent("chunk.m4a")
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        
        try await exportAudioChunk(asset: asset, outputURL: tempURL, startTime: startTime, duration: duration)
        
        let chunkSize = fileSize(at: tempURL)
        let canSplitFurther = duration > (minimumChunkDuration * 1.5)
        
        if chunkSize > preferredChunkUploadBytes && canSplitFurther {
            return try await splitAndTranscribeSegment(
                from: asset,
                apiKey: apiKey,
                startTime: startTime,
                duration: duration
            )
        }
        
        do {
            return try await transcribeSingleFile(url: tempURL, apiKey: apiKey)
        } catch let error as NSError where canSplitFurther && shouldSplitChunkAfterFailure(error) {
            return try await splitAndTranscribeSegment(
                from: asset,
                apiKey: apiKey,
                startTime: startTime,
                duration: duration
            )
        }
    }
    
    private func splitAndTranscribeSegment(from asset: AVAsset, apiKey: String, startTime: TimeInterval, duration: TimeInterval) async throws -> String {
        let firstDuration = duration / 2
        let secondDuration = duration - firstDuration
        
        guard firstDuration > 0, secondDuration > 0 else {
            throw NSError(domain: "CloudAudioTranscriber", code: 11, userInfo: [NSLocalizedDescriptionKey: "Unable to split audio chunk further."])
        }
        
        let firstHalf = try await transcribeSegment(
            from: asset,
            apiKey: apiKey,
            startTime: startTime,
            duration: firstDuration
        )
        
        let secondHalf = try await transcribeSegment(
            from: asset,
            apiKey: apiKey,
            startTime: startTime + firstDuration,
            duration: secondDuration
        )
        
        return [firstHalf, secondHalf]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n[--- Next Segment ---]\n\n")
    }
    
    private func exportAudioChunk(asset: AVAsset, outputURL: URL, startTime: TimeInterval, duration: TimeInterval) async throws {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw NSError(domain: "CloudAudioTranscriber", code: 8, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            let error = exportSession.error ?? NSError(domain: "CloudAudioTranscriber", code: 9, userInfo: [NSLocalizedDescriptionKey: "Export failed"])
            throw error
        }
    }
    
    private func normalizedFileExtension(for url: URL) -> String {
        let fileExtension = url.pathExtension.lowercased()
        return fileExtension.isEmpty ? "m4a" : fileExtension
    }
    
    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension {
        case "mp3":
            return "audio/mpeg"
        case "wav":
            return "audio/wav"
        case "m4a":
            return "audio/mp4"
        case "webm":
            return "audio/webm"
        default:
            return "audio/mp4"
        }
    }
    
    private func fileSize(at url: URL) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.size] as? Int64 ?? 0
    }
}
