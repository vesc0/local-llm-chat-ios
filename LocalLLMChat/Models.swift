import Foundation

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct Message: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var role: MessageRole
    var content: String
    var timestamp: Date = Date()
    var isStreaming: Bool = false
    var isCancelled: Bool = false
    var errorMessage: String? = nil
}

struct Conversation: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var messages: [Message]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var model: String
}

enum ThemeMode: String, Codable, CaseIterable {
    case dark = "Dark"
    case light = "Light"
    case auto = "Auto"
}

enum InferenceEngine: String, Codable, CaseIterable {
    case ollama = "Ollama (Network)"
    case mlx = "MLX-Swift (Local)"
}

struct AppSettings: Codable {
    var ollamaHost: String = "http://172.20.10.5:11434"
    var selectedModel: String = "llama3.1:latest"
    var localModelURL: String = ""
    var localModelName: String = ""
    var engine: InferenceEngine = .mlx
    var themeMode: ThemeMode = .auto
}

struct OllamaStreamChunk: Codable {
    let model: String
    let created_at: String
    let message: OllamaMessageChunk?
    let done: Bool
}

struct OllamaMessageChunk: Codable {
    let role: String
    let content: String
}
