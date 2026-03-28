import Foundation

enum RecordType: String, Codable {
    case client, candidate
}

struct RecordField: Codable, Hashable, Identifiable {
    let key: String
    var value: String

    var id: String { key }
}

enum AIProvider: String, Codable, CaseIterable {
    case gemini = "Gemini"
    case openai = "ChatGPT"
    
    var displayName: String {
        return self.rawValue
    }
}

enum TranscriptionMode: String, Codable, CaseIterable {
    case cloud = "Cloud"
    case local = "Local"
    
    var displayName: String {
        return self.rawValue
    }
}

struct FieldPrompt {
    let field: String
    let prompt: String
}

// New model for database storage of prompts
struct PromptTemplate: Codable, Identifiable {
    let id: String?
    let type: String // "client" or "candidate"
    let field: String
    let prompt: String
    var tags: [String] // Tags for grouping (e.g., ["quick", "deep", "culture"])
    var enabledByDefault: Bool // Whether this prompt should be selected by default
    
    init(id: String? = nil, type: String, field: String, prompt: String, tags: [String] = [], enabledByDefault: Bool = true) {
        self.id = id
        self.type = type
        self.field = field
        self.prompt = prompt
        self.tags = tags
        self.enabledByDefault = enabledByDefault
    }
}

// Model for prompt bundles
struct PromptBundle: Codable, Identifiable {
    let id: String?
    let type: String // "client" or "candidate"
    let name: String // Bundle name (e.g., "Quick Screen", "Deep Dive")
    var promptIds: [String] // IDs of prompts in this bundle
    
    init(id: String? = nil, type: String, name: String, promptIds: [String] = []) {
        self.id = id
        self.type = type
        self.name = name
        self.promptIds = promptIds
    }
}

// AI Configuration
class AIConfiguration: Codable {
    var selectedProvider: AIProvider = .openai
    var transcriptionMode: TranscriptionMode = .cloud
    var openaiApiKey: String = DemoEnvironment.openAIKeyPlaceholder
    var openaiModel: String = "gpt-4o-mini"
    
    static let shared = AIConfiguration()
    
    private init() {}
}

struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            value = str
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let dbl = try? container.decode(Double.self) {
            value = dbl
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let str = value as? String {
            try container.encode(str)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let dbl = value as? Double {
            try container.encode(dbl)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

struct Record: Codable {
    var id: String?
    var name: String
    var type: String
    var fieldKeys: [String]
    var fieldValues: [String]
    var userNotes: String
    var transcript: String?
    var pdfText: String?
    var promptIdsUsed: [String]? // IDs of prompts that were used for this record

    enum CodingKeys: String, CodingKey {
        case id, name, type, fieldKeys, fieldValues, userNotes, transcript, pdfText, promptIdsUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        // Custom decode for fieldKeys/fieldValues
        if let keys = try? container.decode([String].self, forKey: .fieldKeys) {
            fieldKeys = keys
        } else if let anyKeys = try? container.decode([AnyCodable].self, forKey: .fieldKeys) {
            fieldKeys = anyKeys.compactMap { $0.value as? String }
        } else {
            fieldKeys = []
        }
        if let values = try? container.decode([String].self, forKey: .fieldValues) {
            fieldValues = values
        } else if let anyValues = try? container.decode([AnyCodable].self, forKey: .fieldValues) {
            fieldValues = anyValues.compactMap { $0.value as? String }
        } else {
            fieldValues = []
        }
        userNotes = try container.decode(String.self, forKey: .userNotes)
        transcript = try? container.decode(String.self, forKey: .transcript)
        pdfText = try? container.decode(String.self, forKey: .pdfText)
        promptIdsUsed = try? container.decode([String].self, forKey: .promptIdsUsed)
    }

    init(
        id: String? = nil,
        name: String,
        type: String,
        fields: [RecordField],
        userNotes: String,
        transcript: String? = nil,
        pdfText: String? = nil,
        promptIdsUsed: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.fieldKeys = fields.map(\.key)
        self.fieldValues = fields.map(\.value)
        self.userNotes = userNotes
        self.transcript = transcript
        self.pdfText = pdfText
        self.promptIdsUsed = promptIdsUsed
    }

    init(
        id: String? = nil,
        name: String,
        type: String,
        fieldKeys: [String],
        fieldValues: [String],
        userNotes: String,
        transcript: String? = nil,
        pdfText: String? = nil,
        promptIdsUsed: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.fieldKeys = fieldKeys
        self.fieldValues = fieldValues
        self.userNotes = userNotes
        self.transcript = transcript
        self.pdfText = pdfText
        self.promptIdsUsed = promptIdsUsed
    }

    var orderedFields: [RecordField] {
        fieldKeys.enumerated().map { index, key in
            RecordField(
                key: key,
                value: fieldValues.indices.contains(index) ? fieldValues[index] : ""
            )
        }
    }

    mutating func setOrderedFields(_ fields: [RecordField]) {
        fieldKeys = fields.map(\.key)
        fieldValues = fields.map(\.value)
    }

    func value(forFieldKey key: String) -> String? {
        orderedFields.first(where: { $0.key == key })?.value
    }
}
