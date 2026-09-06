import Foundation
import os

protocol ConversationStoring: Sendable {
    func loadConversations() -> [Conversation]
    func loadSettings() -> AppSettings
    func save(conversations: [Conversation]) async
    func save(settings: AppSettings) async
}

struct FileStore: ConversationStoring {
    static let shared = FileStore()

    private let writer = DiskWriter()
    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    func loadConversations() -> [Conversation] {
        var conversations: [Conversation] = Self.read(directory.appending(path: "conversations.json")) ?? []
        // A stream interrupted by termination would otherwise render as "typing" forever.
        for i in conversations.indices {
            for j in conversations[i].messages.indices where conversations[i].messages[j].isStreaming {
                conversations[i].messages[j].isStreaming = false
                conversations[i].messages[j].isCancelled = true
            }
        }
        return conversations
    }

    func loadSettings() -> AppSettings {
        Self.read(directory.appending(path: "settings.json")) ?? AppSettings()
    }

    func save(conversations: [Conversation]) async {
        await writer.write(conversations, to: directory.appending(path: "conversations.json"))
    }

    func save(settings: AppSettings) async {
        await writer.write(settings, to: directory.appending(path: "settings.json"))
    }

    private static func read<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            Logger.app.error("Failed to decode \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}

/// Serializes encoding and writing off the main actor.
private actor DiskWriter {
    func write(_ value: some Encodable, to url: URL) {
        do {
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
        } catch {
            Logger.app.error("Failed to write \(url.lastPathComponent): \(error)")
        }
    }
}
