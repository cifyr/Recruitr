import Foundation

enum DemoEnvironment {
    static let openAIKeyPlaceholder = "YOUR_OPENAI_API_KEY"
    static let geminiKeyPlaceholder = "_YOUR_GEMINI_API_KEY_"
    static let appwriteEndpointPlaceholder = "YOUR_APPWRITE_ENDPOINT"
    static let appwriteProjectPlaceholder = "YOUR_APPWRITE_PROJECT_ID"
    static let appwriteDatabasePlaceholder = "YOUR_APPWRITE_DATABASE_ID"
    static let recordsCollectionPlaceholder = "YOUR_RECORDS_COLLECTION_ID"
    static let promptsCollectionPlaceholder = "YOUR_PROMPTS_COLLECTION_ID"
    static let bundlesCollectionPlaceholder = "YOUR_BUNDLES_COLLECTION_ID"
    static let webhookPlaceholder = "https://example.com/recruitr-demo-webhook"

    static func seededRecords() -> [Record] {
        [
            Record(
                id: "demo-candidate-1",
                name: "Taylor Monroe",
                type: RecordType.candidate.rawValue,
                fields: [
                    RecordField(key: "Candidate Summary", value: "Taylor Monroe is a polished recruiter operations candidate with strong stakeholder communication and a bias toward fast follow-through."),
                    RecordField(key: "Highlights", value: "Built repeatable intake workflows, improved recruiter response times, and coordinated candidate communications across multiple openings."),
                    RecordField(key: "Client Email Draft", value: "Subject: Candidate Summary for Taylor Monroe\n\nTaylor Monroe is a strong recruiter operations profile with practical experience supporting fast-moving hiring teams. Taylor stands out for organization, communication, and comfort turning raw candidate information into clean client-facing updates.")
                ],
                userNotes: "Strong communication skills. Likely a fit for recruiting coordinator and operations support roles.",
                transcript: "Demo transcript: Taylor discussed recruiting coordination, candidate follow-up, and process improvements for a legal recruiting workflow.",
                pdfText: "Demo CV summary: recruiting coordination, intake workflow support, stakeholder communication, CRM hygiene.",
                promptIdsUsed: ["candidate-summary", "candidate-highlights", "candidate-email"]
            ),
            Record(
                id: "demo-client-1",
                name: "North Shore Legal Search",
                type: RecordType.client.rawValue,
                fields: [
                    RecordField(key: "Client Summary", value: "North Shore Legal Search is hiring for a relationship-driven recruiting workflow and values polished communication with both candidates and clients."),
                    RecordField(key: "Requirements Post", value: "We are looking for a recruiter or recruiting coordinator who can turn intake conversations into polished summaries, candidate introductions, and outbound content without slowing the team down.")
                ],
                userNotes: "Primary client profile for demo mode. Wants clean candidate write-ups and faster post-call summaries.",
                transcript: "Demo transcript: client call covered role urgency, ideal communication style, and the need for faster follow-up materials.",
                pdfText: nil,
                promptIdsUsed: ["client-summary", "client-post"]
            )
        ]
    }

    static func seededPrompts() -> [PromptTemplate] {
        [
            PromptTemplate(id: "candidate-summary", type: RecordType.candidate.rawValue, field: "Candidate Summary", prompt: "Create a polished candidate summary.", tags: ["summary", "default"], enabledByDefault: true),
            PromptTemplate(id: "candidate-highlights", type: RecordType.candidate.rawValue, field: "Highlights", prompt: "List the strongest candidate highlights.", tags: ["highlights"], enabledByDefault: true),
            PromptTemplate(id: "candidate-email", type: RecordType.candidate.rawValue, field: "Client Email Draft", prompt: "Draft a concise client-facing intro email for this candidate.", tags: ["email"], enabledByDefault: true),
            PromptTemplate(id: "candidate-post", type: RecordType.candidate.rawValue, field: "Recruiter Post", prompt: "Create a short recruiter-style post about this candidate.", tags: ["post"], enabledByDefault: false),
            PromptTemplate(id: "client-summary", type: RecordType.client.rawValue, field: "Client Summary", prompt: "Summarize the client conversation and needs.", tags: ["summary", "default"], enabledByDefault: true),
            PromptTemplate(id: "client-post", type: RecordType.client.rawValue, field: "Requirements Post", prompt: "Draft a requirements-style post based on the client call.", tags: ["post"], enabledByDefault: true),
            PromptTemplate(id: "client-email", type: RecordType.client.rawValue, field: "Internal Follow-up", prompt: "Draft an internal follow-up note for the recruiting team.", tags: ["email"], enabledByDefault: false)
        ]
    }

    static func seededBundles() -> [PromptBundle] {
        [
            PromptBundle(
                id: "candidate-quick-screen",
                type: RecordType.candidate.rawValue,
                name: "Quick Screen",
                promptIds: ["candidate-summary", "candidate-highlights"]
            ),
            PromptBundle(
                id: "candidate-client-ready",
                type: RecordType.candidate.rawValue,
                name: "Client Ready",
                promptIds: ["candidate-summary", "candidate-highlights", "candidate-email"]
            )
        ]
    }

    static func demoTranscript(for url: URL, mode: TranscriptionMode) -> String {
        let fileLabel = prettifyFilename(url)
        return """
        [Recruitr demo transcript]
        Source file: \(fileLabel)
        Mode: \(mode.displayName)

        This public GitHub variant uses local demo output instead of a live transcription service. The conversation covered candidate background, current role, strengths, compensation expectations, and recruiting priorities.
        """
    }

    static func demoFieldValue(prompt: FieldPrompt, context: String, name: String?, provider: AIProvider) -> String {
        let personName = sanitizedName(name)
        let snippet = contextSnippet(from: context)
        let field = prompt.field.lowercased()

        if field.contains("email") {
            return """
            Subject: Candidate Summary for \(personName)

            \(personName) stands out in this Recruitr demo as a polished recruiting profile with clear communication, strong follow-through, and useful contextual detail from the uploaded call notes and documents.

            Key takeaways:
            - \(snippet)
            - Output generated in \(provider.displayName) demo mode
            - Public-safe mock content for GitHub sharing
            """
        }

        if field.contains("post") {
            return """
            Recruitr demo post: \(personName) brings a polished communication style, practical recruiting workflow support, and the ability to turn raw call information into clean client-facing materials. Key context: \(snippet)
            """
        }

        if field.contains("highlight") || field.contains("skill") {
            return """
            - Strong communication and follow-up cadence
            - Comfortable organizing recruiting information into clear summaries
            - Demo insight based on uploaded materials: \(snippet)
            """
        }

        if field.contains("comp") {
            return "\(personName) is presented in demo mode as flexible on compensation and focused more on fit, pace, and long-term opportunity than maximizing short-term salary."
        }

        if field.contains("location") {
            return "Chicago, IL (demo profile)"
        }

        if field.contains("requirement") || field.contains("role") {
            return "This Recruitr demo indicates the client wants a polished, responsive recruiting workflow with stronger summaries, faster candidate follow-up, and content that is immediately ready to share. Key context: \(snippet)"
        }

        return "\(personName) is represented in this Recruitr demo as a strong recruiting profile. This field was generated locally in \(provider.displayName) demo mode using uploaded notes/files. Key context: \(snippet)"
    }

    private static func contextSnippet(from context: String) -> String {
        let cleaned = context
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return "uploaded notes and files were limited, so the demo output used a generic recruiting summary"
        }

        if cleaned.count <= 180 {
            return cleaned
        }

        let cutoff = cleaned.index(cleaned.startIndex, offsetBy: 180)
        return "\(cleaned[..<cutoff])..."
    }

    private static func sanitizedName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "This profile" : trimmed
    }

    private static func prettifyFilename(_ url: URL) -> String {
        url.deletingPathExtension()
            .lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}

actor DemoStore {
    static let shared = DemoStore()

    private var records: [Record]
    private var prompts: [PromptTemplate]
    private var bundles: [PromptBundle]

    init() {
        records = DemoEnvironment.seededRecords()
        prompts = DemoEnvironment.seededPrompts()
        bundles = DemoEnvironment.seededBundles()
    }

    func fetchRecords() -> [Record] {
        records
    }

    func createRecord(_ record: Record) -> Record {
        let saved = Record(
            id: record.id ?? "record-\(UUID().uuidString)",
            name: record.name,
            type: record.type,
            fields: record.orderedFields,
            userNotes: record.userNotes,
            transcript: record.transcript,
            pdfText: record.pdfText,
            promptIdsUsed: record.promptIdsUsed
        )
        records.insert(saved, at: 0)
        return saved
    }

    func updateRecord(_ record: Record) throws -> Record {
        guard let id = record.id else {
            throw NSError(domain: "RecruitrDemoStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Record ID is missing in demo mode."])
        }
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "RecruitrDemoStore", code: 2, userInfo: [NSLocalizedDescriptionKey: "Record not found in demo mode."])
        }
        records[index] = record
        return record
    }

    func deleteRecord(_ record: Record) {
        records.removeAll { $0.id == record.id }
    }

    func fetchPromptTemplates(type: String?) -> [PromptTemplate] {
        guard let type else { return prompts }
        return prompts.filter { $0.type == type }
    }

    func createPromptTemplate(_ prompt: PromptTemplate, preserveProvidedID: Bool) -> PromptTemplate {
        let stored = PromptTemplate(
            id: preserveProvidedID ? (prompt.id ?? "prompt-\(UUID().uuidString)") : "prompt-\(UUID().uuidString)",
            type: prompt.type,
            field: prompt.field,
            prompt: prompt.prompt,
            tags: prompt.tags,
            enabledByDefault: prompt.enabledByDefault
        )
        prompts.append(stored)
        return stored
    }

    func updatePromptTemplate(_ prompt: PromptTemplate) throws -> PromptTemplate {
        guard let id = prompt.id else {
            throw NSError(domain: "RecruitrDemoStore", code: 3, userInfo: [NSLocalizedDescriptionKey: "Prompt ID is missing in demo mode."])
        }
        guard let index = prompts.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "RecruitrDemoStore", code: 4, userInfo: [NSLocalizedDescriptionKey: "Prompt not found in demo mode."])
        }
        prompts[index] = prompt
        return prompt
    }

    func deletePromptTemplate(_ prompt: PromptTemplate) {
        prompts.removeAll { $0.id == prompt.id }
        for index in bundles.indices {
            bundles[index].promptIds.removeAll { $0 == prompt.id }
        }
    }

    func fetchPromptBundles(type: String?) -> [PromptBundle] {
        guard let type else { return bundles }
        return bundles.filter { $0.type == type }
    }

    func createPromptBundle(_ bundle: PromptBundle) -> PromptBundle {
        let stored = PromptBundle(
            id: bundle.id ?? "bundle-\(UUID().uuidString)",
            type: bundle.type,
            name: bundle.name,
            promptIds: bundle.promptIds
        )
        bundles.append(stored)
        return stored
    }

    func updatePromptBundle(_ bundle: PromptBundle) throws -> PromptBundle {
        guard let id = bundle.id else {
            throw NSError(domain: "RecruitrDemoStore", code: 5, userInfo: [NSLocalizedDescriptionKey: "Bundle ID is missing in demo mode."])
        }
        guard let index = bundles.firstIndex(where: { $0.id == id }) else {
            throw NSError(domain: "RecruitrDemoStore", code: 6, userInfo: [NSLocalizedDescriptionKey: "Bundle not found in demo mode."])
        }
        bundles[index] = bundle
        return bundle
    }

    func deletePromptBundle(_ bundle: PromptBundle) {
        bundles.removeAll { $0.id == bundle.id }
    }
}
