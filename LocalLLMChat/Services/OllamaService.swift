import Foundation

struct OllamaService: ChatService {
    let host: URL
    let model: String

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    private static let discoverySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 5
        return URLSession(configuration: config)
    }()

    func stream(_ messages: [Message]) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await Self.session.bytes(for: chatRequest(messages))
                    try Self.validate(response)
                    var isThinking = false
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else { continue }
                        let text = Self.render(chunk.message, isThinking: &isThinking)
                        if !text.isEmpty { continuation.yield(text) }
                    }
                    // A reasoning model may end mid-thought if the stream is cut short.
                    if isThinking { continuation.yield("\n</think>\n") }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func fetchModels(host: String) async throws -> [String] {
        guard let url = URL(string: host)?.appending(path: "api/tags") else {
            throw ChatServiceError.invalidHost(host)
        }
        let (data, response) = try await discoverySession.data(from: url)
        try validate(response)
        return try JSONDecoder().decode(TagsResponse.self, from: data).models.map(\.name)
    }

    // MARK: - Request

    private func chatRequest(_ messages: [Message]) async throws -> URLRequest {
        var request = URLRequest(url: host.appending(path: "api/chat"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [[String: Any]] = []
        for message in messages {
            var entry: [String: Any] = ["role": message.role.rawValue, "content": message.content]
            let images = await AttachmentStore.shared.base64Images(for: message.attachments ?? [])
            if !images.isEmpty { entry["images"] = images }
            payload.append(entry)
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "messages": payload, "stream": true,
        ])
        return request
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else { throw ChatServiceError.server(http.statusCode) }
    }

    /// Wraps Ollama's separate `thinking` field in the `<think>` tags the UI parses.
    private static func render(_ message: MessageChunk?, isThinking: inout Bool) -> String {
        var out = ""
        if let thinking = message?.thinking, !thinking.isEmpty {
            if !isThinking { isThinking = true; out += "<think>\n" }
            out += thinking
        }
        if let content = message?.content, !content.isEmpty {
            if isThinking { isThinking = false; out += "\n</think>\n" }
            out += content
        }
        return out
    }

    // MARK: - Wire format

    private struct StreamChunk: Decodable { let message: MessageChunk? }
    private struct MessageChunk: Decodable { let content: String?; let thinking: String? }
    private struct TagsResponse: Decodable {
        struct Tag: Decodable { let name: String }
        let models: [Tag]
    }
}
