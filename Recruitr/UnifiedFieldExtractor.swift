import Foundation

class UnifiedFieldExtractor {
    static let shared = UnifiedFieldExtractor()
    
    func extractSingleField(prompt: FieldPrompt, context: String, name: String?) async throws -> String {
        DemoEnvironment.demoFieldValue(
            prompt: prompt,
            context: context,
            name: name,
            provider: AIConfiguration.shared.selectedProvider
        )
    }
    
    func extractFields(prompts: [FieldPrompt], context: String, name: String?) async throws -> [String: String] {
        let provider = AIConfiguration.shared.selectedProvider
        var result: [String: String] = [:]

        for prompt in prompts {
            result[prompt.field] = DemoEnvironment.demoFieldValue(
                prompt: prompt,
                context: context,
                name: name,
                provider: provider
            )
        }

        return result
    }
} 
