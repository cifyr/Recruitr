import Foundation
import GoogleGenerativeAI

enum APIKey {
    static func `default`() throws -> String {
        guard let filePath = Bundle.main.path(forResource: "GenerativeAI-Info", ofType: "plist") else {
            throw ConfigurationError.missingGeminiPlist
        }
        let plist = NSDictionary(contentsOfFile: filePath)
        guard let value = plist?.object(forKey: "API_KEY") as? String else {
            throw ConfigurationError.missingGeminiAPIKey
        }
        if value.starts(with: "_") {
            throw ConfigurationError.placeholderGeminiAPIKey
        }
        return value
    }
}

class GeminiFieldExtractor {
    static let shared = GeminiFieldExtractor()

    func extractFields(prompts: [FieldPrompt], context: String, name: String?) async throws -> [String: String] {
        let model = GenerativeModel(name: "gemini-2.0-flash-lite", apiKey: try APIKey.default())
        var result: [String: String] = [:]
        for prompt in prompts {
            var fullPrompt: String
            if prompt.field.lowercased() == "name" {
                fullPrompt = "\(prompt.prompt)\n\n\(context)"
            } else if let name = name, !name.isEmpty {
                fullPrompt = "\(prompt.prompt)\n\nCandidate/Client Name: \(name)\n\n\(context)"
            } else {
                fullPrompt = "\(prompt.prompt)\n\n\(context)"
            }
            do {
                let response = try await model.generateContent(fullPrompt)
                result[prompt.field] = response.text ?? ""
            } catch {
                AppLogger.ai.error("Gemini error for field \(prompt.field, privacy: .public): \(error.localizedDescription)")
                result[prompt.field] = "[Gemini error: \(error.localizedDescription)]"
            }
        }
        return result
    }
    
    func extractSingleField(prompt: FieldPrompt, context: String, name: String?) async throws -> String {
        let model = GenerativeModel(name: "gemini-2.0-flash-lite", apiKey: try APIKey.default())
        
        var fullPrompt: String
        if prompt.field.lowercased() == "name" {
            fullPrompt = "\(prompt.prompt)\n\n\(context)"
        } else if let name = name, !name.isEmpty {
            fullPrompt = "\(prompt.prompt)\n\nCandidate/Client Name: \(name)\n\n\(context)"
        } else {
            fullPrompt = "\(prompt.prompt)\n\n\(context)"
        }
        
        do {
            let response = try await model.generateContent(fullPrompt)
            return response.text ?? ""
        } catch {
            AppLogger.ai.error("Gemini error for field \(prompt.field, privacy: .public): \(error.localizedDescription)")
            throw error
        }
    }
} 
