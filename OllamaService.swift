import Foundation

class OllamaService {
    static let shared = OllamaService()
    
    func streamChat(messages: [Message], settings: AppSettings, onToken: @escaping (String) -> Void) async throws {
        let endpoint = "\(settings.ollamaHost)/api/chat"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let apiMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = [
            "model": settings.selectedModel,
            "messages": apiMessages,
            "stream": true
        ]
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (result, response) = try await session.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        for try await line in result.lines {
            guard let data = line.data(using: .utf8) else { continue }
            if let chunk = try? JSONDecoder().decode(OllamaStreamChunk.self, from: data) {
                if let content = chunk.message?.content {
                    await MainActor.run {
                        onToken(content)
                    }
                }
            }
        }
    }
    
    func generateChat(messages: [Message], settings: AppSettings) async throws -> String {
        let endpoint = "\(settings.ollamaHost)/api/chat"
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let apiMessages = messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = [
            "model": settings.selectedModel,
            "messages": apiMessages,
            "stream": false
        ]
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: config)
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        struct OllamaResponse: Codable {
            let message: OllamaMessageChunk?
        }
        
        let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return result.message?.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
