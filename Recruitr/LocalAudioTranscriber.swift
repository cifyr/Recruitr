import Foundation
import SwiftWhisper
import AVFoundation
import Accelerate

class LocalAudioTranscriber {
    static let shared = LocalAudioTranscriber()
    
    private var whisper: Whisper?
    
    private init() {}
    
    func transcribeAudio(url: URL) async throws -> String {
        let whisper = try loadWhisper()
        let audioFrames = try Self.convertAudioFileToPCMArray(fileURL: url)
        let segments = try await whisper.transcribe(audioFrames: audioFrames)
        return segments.map(\.text).joined()
    }

    private func loadWhisper() throws -> Whisper {
        if let whisper {
            return whisper
        }

        guard let modelURL = Bundle.main.url(
            forResource: "ggml-small.en",
            withExtension: "bin"
        ) else {
            throw ConfigurationError.missingWhisperModel
        }

        let whisper = Whisper(fromFileURL: modelURL)
        self.whisper = whisper
        return whisper
    }
    
    static func convertAudioFileToPCMArray(fileURL: URL) throws -> [Float] {
        // Try to access security-scoped resource (for files from file picker)
        // If it returns false, the URL might be a regular file URL (from drag & drop) which doesn't need security-scoped access
        let hasSecurityScopedAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let asset = AVAsset(url: fileURL)
        let reader = try AVAssetReader(asset: asset)
        
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "LocalAudioTranscriber", code: 2, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(output)
        reader.startReading()
        
        var floats: [Float] = []
        floats.reserveCapacity(Int(track.timeRange.duration.seconds * 16_000))
        
        while let buffer = output.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(buffer) {
            
            let length = CMBlockBufferGetDataLength(blockBuffer)
            let sampleCount = length / MemoryLayout<Int16>.size
            
            var int16Buffer = [Int16](repeating: 0, count: sampleCount)
            CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: length,
                destination: &int16Buffer
            )
            
            var floatBuffer = [Float](repeating: 0, count: sampleCount)
            vDSP_vflt16(int16Buffer, 1, &floatBuffer, 1, vDSP_Length(sampleCount))
            
            var scale: Float = 1.0 / 32767.0
            vDSP_vsmul(floatBuffer, 1, &scale, &floatBuffer, 1, vDSP_Length(sampleCount))
            
            floats.append(contentsOf: floatBuffer)
            CMSampleBufferInvalidate(buffer)
        }
        
        return floats
    }
}
