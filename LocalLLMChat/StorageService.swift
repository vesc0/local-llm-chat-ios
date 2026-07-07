import Foundation

class StorageService {
    static let shared = StorageService()
    private let conversationsKey = "localllm.conversations"
    private let settingsKey = "localllm.settings"
    
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var conversationsFileURL: URL {
        documentsDirectory.appendingPathComponent("conversations.json")
    }
    
    private var settingsFileURL: URL {
        documentsDirectory.appendingPathComponent("settings.json")
    }
    
    func saveConversations(_ conversations: [Conversation]) {
        do {
            let data = try JSONEncoder().encode(conversations)
            try data.write(to: conversationsFileURL)
        } catch {
            print("Failed to save conversations: \(error)")
        }
    }
    
    func loadConversations() -> [Conversation] {
        guard fileManager.fileExists(atPath: conversationsFileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: conversationsFileURL)
            return try JSONDecoder().decode([Conversation].self, from: data)
        } catch {
            print("Failed to load conversations: \(error)")
            return []
        }
    }
    
    func saveSettings(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsFileURL)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func loadSettings() -> AppSettings {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return AppSettings() }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
            return AppSettings()
        }
    }
}
