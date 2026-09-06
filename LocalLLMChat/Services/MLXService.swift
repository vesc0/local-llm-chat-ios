import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

struct MLXChatService: ChatService {
    let modelId: String

    func stream(_ messages: [Message]) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await MLXRuntime.shared.generate(messages, modelId: modelId) {
                        continuation.yield($0)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Owns the loaded model. An actor because the container is expensive to build
/// and must not be torn down while inference is running.
actor MLXRuntime {
    static let shared = MLXRuntime()

    private var container: ModelContainer?
    private var loadedModelId: String?

    func generate(_ messages: [Message], modelId: String, onToken: @Sendable (String) -> Void) async throws {
        let container = try await load(modelId)
        let input = try await container.prepare(input: UserInput(chat: messages.map(\.mlxMessage)))

        for try await generation in try await container.generate(
            input: input, parameters: GenerateParameters(temperature: 0.6)
        ) {
            try Task.checkCancellation()
            if case .chunk(let text) = generation { onToken(text) }
        }
    }

    func unload() {
        container = nil
        loadedModelId = nil
        MLX.Memory.clearCache()
    }

    private func load(_ modelId: String) async throws -> ModelContainer {
        if let container, loadedModelId == modelId { return container }
        MLX.Memory.cacheLimit = 20 * 1024 * 1024
        let container = try await #huggingFaceLoadModelContainer(
            configuration: ModelConfiguration(id: modelId)
        )
        self.container = container
        loadedModelId = modelId
        return container
    }
}

private extension Message {
    var mlxMessage: Chat.Message {
        switch role {
        case .user: .user(content)
        case .assistant: .assistant(content)
        case .system: .system(content)
        }
    }
}
