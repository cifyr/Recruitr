import Foundation

// OpenAI API Response Models
struct OpenAIResponse: Codable {
    let choices: [Choice]
}

struct Choice: Codable {
    let message: Message
}

struct Message: Codable {
    let content: String?
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIError
}

struct OpenAIError: Codable {
    let message: String
    let code: String?
}

class OpenAIFieldExtractor {
    static let shared = OpenAIFieldExtractor()
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func extractSingleField(prompt: FieldPrompt, context: String, name: String?, apiKey: String, model: String = "gpt-4o-mini") async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "OpenAIFieldExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key is required"])
        }
        
        var fullPrompt: String
        if prompt.field.lowercased() == "name" {
            fullPrompt = "\(prompt.prompt)\n\n\(context)"
        } else if let name = name, !name.isEmpty {
            fullPrompt = "\(prompt.prompt)\n\nCandidate/Client Name: \(name)\n\n\(context)"
        } else {
            fullPrompt = "\(prompt.prompt)\n\n\(context)"
        }
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "user",
                    "content": fullPrompt
                ]
            ],
            "temperature": 0.1,
            "max_tokens": 2000
        ]
        
        guard let url = URL(string: baseURL) else {
            throw NSError(domain: "OpenAIFieldExtractor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw NSError(domain: "OpenAIFieldExtractor", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize request: \(error.localizedDescription)"])
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "OpenAIFieldExtractor", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAIFieldExtractor", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
        }
        
        // Parse the response
        do {
            let response = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            if let choice = response.choices.first,
               let content = choice.message.content {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                throw NSError(domain: "OpenAIFieldExtractor", code: 500, userInfo: [NSLocalizedDescriptionKey: "No content in OpenAI response"])
            }
        } catch {
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                let errorMessage = errorResponse.error.message
                let errorCode = errorResponse.error.code ?? "unknown"
                
                // Check for quota error
                if errorCode == "insufficient_quota" {
                    throw NSError(domain: "OpenAIFieldExtractor", code: 429, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
                }
                
                throw NSError(domain: "OpenAIFieldExtractor", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorMessage)"])
            }
            
            throw NSError(domain: "OpenAIFieldExtractor", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI response: \(error.localizedDescription)"])
        }
    }
} 