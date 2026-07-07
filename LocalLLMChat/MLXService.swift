import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

class MLXService {
    static let shared = MLXService()
    
    private var modelContainer: ModelContainer?
    private var currentModelId: String = ""
    private var isLoaded: Bool = false
    
    func streamChat(messages: [Message], modelId: String, onToken: @escaping (String) -> Void) async throws {
        if !isLoaded || currentModelId != modelId {
            MLX.Memory.cacheLimit = 20 * 1024 * 1024
            let configuration = ModelConfiguration(id: modelId)
            self.modelContainer = try await #huggingFaceLoadModelContainer(configuration: configuration)
            self.currentModelId = modelId
            self.isLoaded = true
        }
        
        guard let container = modelContainer else {
            throw URLError(.badServerResponse)
        }
        
        // Convert to Chat.Message format
        let chatMessages = messages.map { msg -> Chat.Message in
            switch msg.role {
            case .user: return .user(msg.content)
            case .assistant: return .assistant(msg.content)
            case .system: return .system(msg.content)
            }
        }
        
        let userInput = UserInput(chat: chatMessages)
        let lmInput = try await container.prepare(input: userInput)
        
        let generateParams = GenerateParameters(temperature: 0.6)
        
        let stream = try await container.generate(input: lmInput, parameters: generateParams)
        
        for try await generation in stream {
            switch generation {
            case .chunk(let text):
                await MainActor.run { onToken(text) }
            case .toolCall, .info:
                break
            }
        }
    }
    
    func generateChat(messages: [Message], modelId: String) async throws -> String {
        var fullResponse = ""
        try await streamChat(messages: messages, modelId: modelId) { token in
            fullResponse += token
        }
        return fullResponse
    }
}
