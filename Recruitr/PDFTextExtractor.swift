import Foundation
import PDFKit

class PDFTextExtractor {
    static let shared = PDFTextExtractor()
    
    func extractText(from url: URL) async throws -> String {
        guard let pdf = PDFDocument(url: url) else {
            throw NSError(domain: "PDFTextExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open PDF."])
        }
        var text = ""
        for i in 0..<pdf.pageCount {
            if let page = pdf.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text
    }
} 