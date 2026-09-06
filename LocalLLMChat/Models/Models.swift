import Foundation

enum MessageRole: String, Codable, Sendable {
    case user, assistant, system
}

enum AttachmentType: String, Codable, Sendable {
    case image, pdf, text
}

struct Attachment: Identifiable, Codable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var type: AttachmentType
    /// Name of the file inside the attachments directory. Absolute paths are not
    /// stored because the sandbox container UUID changes between launches.
    var filename: String?
    var extractedText: String?

    private enum Keys: String, CodingKey { case id, type, filename, extractedText }
    private enum LegacyKeys: String, CodingKey { case url }

    init(id: String = UUID().uuidString, type: AttachmentType, filename: String? = nil, extractedText: String? = nil) {
        self.id = id
        self.type = type
        self.filename = filename
        self.extractedText = extractedText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        type = try c.decode(AttachmentType.self, forKey: .type)
        extractedText = try c.decodeIfPresent(String.self, forKey: .extractedText)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        filename = try c.decodeIfPresent(String.self, forKey: .filename)
            ?? (try legacy.decodeIfPresent(URL.self, forKey: .url))?.lastPathComponent
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode(type, forKey: .type)
        try c.encodeIfPresent(filename, forKey: .filename)
        try c.encodeIfPresent(extractedText, forKey: .extractedText)
    }
}

struct Message: Identifiable, Codable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var role: MessageRole
    var content: String
    var timestamp: Date = Date()
    var isStreaming: Bool = false
    var isCancelled: Bool = false
    var thoughtTime: TimeInterval? = nil
    var errorMessage: String? = nil
    var attachments: [Attachment]? = nil
}

struct Conversation: Identifiable, Codable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var title: String
    var messages: [Message]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var model: String

    var attachmentFilenames: [String] {
        messages.flatMap { $0.attachments ?? [] }.compactMap(\.filename)
    }
}

enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case dark = "Dark", light = "Light", auto = "Auto"
}

enum InferenceEngine: String, Codable, CaseIterable, Sendable {
    case ollama = "Ollama (Network)"
    case mlx = "MLX-Swift (Local)"
}

struct AppSettings: Codable, Equatable, Sendable {
    var ollamaHost: String = ""
    var selectedModel: String = ""
    var localModelName: String = ""
    var engine: InferenceEngine = .mlx
    var themeMode: ThemeMode = .auto
}
