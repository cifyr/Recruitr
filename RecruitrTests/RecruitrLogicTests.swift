import Foundation
import Testing
@testable import Recruitr

struct RecruitrLogicTests {

    @Test
    func recordPreservesOrderedFieldsRoundTrip() {
        let fields = [
            RecordField(key: "summary", value: "First"),
            RecordField(key: "skills", value: "Second")
        ]

        var record = Record(
            name: "Taylor",
            type: RecordType.candidate.rawValue,
            fields: fields,
            userNotes: "notes"
        )

        #expect(record.fieldKeys == ["summary", "skills"])
        #expect(record.fieldValues == ["First", "Second"])
        #expect(record.orderedFields == fields)

        record.setOrderedFields([
            RecordField(key: "skills", value: "Updated"),
            RecordField(key: "summary", value: "Moved")
        ])

        #expect(record.fieldKeys == ["skills", "summary"])
        #expect(record.fieldValues == ["Updated", "Moved"])
        #expect(record.value(forFieldKey: "summary") == "Moved")
    }

    @Test
    func candidatePromptSelectionDefaultsToEnabledPrompts() {
        let prompts = [
            PromptTemplate(id: "1", type: "candidate", field: "summary", prompt: "Summary", tags: [], enabledByDefault: true),
            PromptTemplate(id: "2", type: "candidate", field: "notes", prompt: "Notes", tags: [], enabledByDefault: false)
        ]

        let resolved = RecordProcessingSupport.promptsToUse(
            for: .candidate,
            candidatePrompts: prompts,
            clientPrompts: [],
            selectedPromptIds: []
        )

        #expect(resolved.map(\.field) == ["summary"])
    }

    @Test
    func candidatePromptSelectionFallsBackToAllWhenNothingEnabled() {
        let prompts = [
            PromptTemplate(id: "1", type: "candidate", field: "summary", prompt: "Summary", tags: [], enabledByDefault: false),
            PromptTemplate(id: "2", type: "candidate", field: "notes", prompt: "Notes", tags: [], enabledByDefault: false)
        ]

        let resolved = RecordProcessingSupport.promptsToUse(
            for: .candidate,
            candidatePrompts: prompts,
            clientPrompts: [],
            selectedPromptIds: []
        )

        #expect(resolved.map(\.field) == ["summary", "notes"])
    }

    @Test
    func candidatePromptSelectionRespectsManualSelection() {
        let prompts = [
            PromptTemplate(id: "1", type: "candidate", field: "summary", prompt: "Summary"),
            PromptTemplate(id: "2", type: "candidate", field: "notes", prompt: "Notes")
        ]

        let resolved = RecordProcessingSupport.promptsToUse(
            for: .candidate,
            candidatePrompts: prompts,
            clientPrompts: [],
            selectedPromptIds: ["2"]
        )

        #expect(resolved.map(\.field) == ["notes"])
    }

    @Test
    func combinedContextKeepsBaseContextAndExtractedFields() {
        let context = RecordProcessingSupport.combinedContext(
            baseContext: "Candidate notes",
            extractedFields: [
                RecordField(key: "summary", value: "Strong recruiter"),
                RecordField(key: "location", value: "Chicago")
            ]
        )

        #expect(context.contains("Candidate notes"))
        #expect(context.contains("summary:\nStrong recruiter"))
        #expect(context.contains("location:\nChicago"))
    }

    @Test
    func webhookURLUsesURLComponentsEncoding() throws {
        let record = Record(
            name: "Ava & Ben",
            type: RecordType.client.rawValue,
            fields: [],
            userNotes: ""
        )

        let url = try #require(WebhookService.shared.makeNotificationURL(for: record))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(items["name"] == "Ava & Ben")
        #expect(items["type"] == RecordType.client.rawValue)
    }

    @Test
    func docxXMLExtractionPullsOutText() {
        let xml = """
        <w:document>
          <w:body>
            <w:p><w:r><w:t>Hello</w:t></w:r></w:p>
            <w:p><w:r><w:t>World</w:t></w:r></w:p>
          </w:body>
        </w:document>
        """

        let text = DocumentTextExtractor.extractTextFromDOCXXML(xml)

        #expect(text.contains("Hello"))
        #expect(text.contains("World"))
    }
}
