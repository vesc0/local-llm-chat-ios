import XCTest
@testable import LocalLLMChat

struct StubChatService: ChatService {
    var tokens: [String] = []
    var failure: StubError?

    func stream(_ messages: [Message]) -> AsyncThrowingStream<String, any Error> {
        AsyncThrowingStream { continuation in
            if let failure {
                continuation.finish(throwing: failure)
            } else {
                tokens.forEach { continuation.yield($0) }
                continuation.finish()
            }
        }
    }
}

enum StubError: Error, Sendable {
    case boom
}

final class MemoryStore: ConversationStoring, @unchecked Sendable {
    var conversations: [Conversation] = []
    var settings = AppSettings()

    func loadConversations() -> [Conversation] { conversations }
    func loadSettings() -> AppSettings { settings }
    func save(conversations: [Conversation]) async { self.conversations = conversations }
    func save(settings: AppSettings) async { self.settings = settings }
}

@MainActor
func waitUntil(
    _ condition: () -> Bool,
    timeout: TimeInterval = 2,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            return XCTFail("Timed out waiting for condition", file: file, line: line)
        }
        try? await Task.sleep(for: .milliseconds(5))
    }
}
