import Foundation
import PDFKit
import UniformTypeIdentifiers

class DocumentTextExtractor {
    static let shared = DocumentTextExtractor()
    
    func extractText(from url: URL) async throws -> String {
        let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let securedURL = url
        return try await Task.detached(priority: .userInitiated) {
            try Self.extractTextSynchronously(from: securedURL)
        }.value
    }
    
    static func extractTextSynchronously(from url: URL) throws -> String {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return try extractPDFText(from: url)
        case "docx":
            return try extractDOCXText(from: url)
        default:
            throw NSError(domain: "DocumentTextExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type: \(fileExtension)"])
        }
    }

    private static func extractPDFText(from url: URL) throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw NSError(domain: "DocumentTextExtractor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF file."])
        }
        
        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text
    }
    
    private static func extractDOCXText(from url: URL) throws -> String {
        do {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }
            
            let tempDocxPath = tempDir.appendingPathComponent("document.docx")
            try FileManager.default.copyItem(at: url, to: tempDocxPath)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-q", tempDocxPath.path, "-d", tempDir.path]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                throw NSError(domain: "DocumentTextExtractor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to extract DOCX file contents."])
            }
            
            let documentXMLPath = tempDir.appendingPathComponent("word").appendingPathComponent("document.xml")
            
            guard FileManager.default.fileExists(atPath: documentXMLPath.path) else {
                throw NSError(domain: "DocumentTextExtractor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not find document.xml in DOCX file."])
            }
            
            let xmlData = try Data(contentsOf: documentXMLPath)
            let xmlString = String(data: xmlData, encoding: .utf8) ?? ""
            
            return extractTextFromDOCXXML(xmlString)
            
        } catch {
            throw NSError(domain: "DocumentTextExtractor", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to extract text from DOCX: \(error.localizedDescription)"])
        }
    }
    
    static func extractTextFromDOCXXML(_ xmlString: String) -> String {
        var text = ""
        var currentText = ""
        
        let textElements = xmlString.components(separatedBy: "<w:t>")
        
        for element in textElements {
            guard let endRange = element.range(of: "</w:t>") else {
                continue
            }

            let extractedText = String(element[..<endRange.lowerBound])
            currentText += extractedText
        }
        
        let pattern = "<w:t[^>]*>(.*?)</w:t>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        
        if let regex = regex {
            let range = NSRange(xmlString.startIndex..<xmlString.endIndex, in: xmlString)
            let matches = regex.matches(in: xmlString, options: [], range: range)
            
            for match in matches {
                if let range = Range(match.range(at: 1), in: xmlString) {
                    let extractedText = String(xmlString[range])
                    text += extractedText + " "
                }
            }
        }
        
        if text.isEmpty {
            text = currentText
        }
        
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        
        text = text.replacingOccurrences(of: "</w:p>", with: "\n")
        
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: " \n ", with: "\n")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return text
    }
} 
