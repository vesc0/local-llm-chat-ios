import Foundation
import os

extension Logger {
    static let app = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LocalLLMChat", category: "app")
}

/// A backend capable of continuing a conversation, one token at a time.
protocol ChatService: Sendable {
    func stream(_ messages: [Message]) -> AsyncThrowingStream<String, any Error>
}

extension ChatService {
    /// Collects a full response. Used for non-interactive work such as titling.
    func generate(_ messages: [Message]) async throws -> String {
        var output = ""
        for try await token in stream(messages) { output += token }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ChatServiceError: LocalizedError {
    case noModelSelected(InferenceEngine)
    case invalidHost(String)
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .noModelSelected(.mlx):
            "No MLX model selected. Choose one in Settings › Manage Downloaded Models."
        case .noModelSelected(.ollama):
            "No Ollama model selected. Choose one in Settings › Select Ollama Model."
        case .invalidHost(let host):
            "\"\(host)\" is not a valid Ollama host. Use a form like http://192.168.1.10:11434."
        case .server(let code):
            "The server responded with status \(code)."
        }
    }
}

/// Builds the service matching the user's current engine selection.
/// Injected into `ChatViewModel` so tests can substitute a stub.
@Sendable func makeChatService(for settings: AppSettings) throws -> any ChatService {
    switch settings.engine {
    case .ollama:
        guard !settings.selectedModel.isEmpty else { throw ChatServiceError.noModelSelected(.ollama) }
        guard let url = URL(string: settings.ollamaHost), url.scheme != nil, url.host != nil else {
            throw ChatServiceError.invalidHost(settings.ollamaHost)
        }
        return OllamaService(host: url, model: settings.selectedModel)
    case .mlx:
        guard !settings.localModelName.isEmpty else { throw ChatServiceError.noModelSelected(.mlx) }
        return MLXChatService(modelId: settings.localModelName)
    }
}
