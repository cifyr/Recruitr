import Foundation

enum RecordProcessingSupport {
    static func promptsToUse(
        for type: RecordType,
        candidatePrompts: [PromptTemplate],
        clientPrompts: [PromptTemplate],
        selectedPromptIds: Set<String>
    ) -> [PromptTemplate] {
        switch type {
        case .client:
            return clientPrompts
        case .candidate:
            guard !selectedPromptIds.isEmpty else {
                let enabledPrompts = candidatePrompts.filter(\.enabledByDefault)
                return enabledPrompts.isEmpty ? candidatePrompts : enabledPrompts
            }

            return candidatePrompts.filter { prompt in
                guard let id = prompt.id else { return false }
                return selectedPromptIds.contains(id)
            }
        }
    }

    static func combinedContext(baseContext: String, extractedFields: [RecordField]) -> String {
        guard !extractedFields.isEmpty else {
            return baseContext
        }

        let fieldContext = extractedFields
            .map { "\($0.key):\n\($0.value)" }
            .joined(separator: "\n\n")

        if baseContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fieldContext
        }

        return "\(baseContext)\n\n\(fieldContext)"
    }
}
