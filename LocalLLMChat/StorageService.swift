import Foundation
import UIKit

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
    
    private var attachmentsDirectory: URL {
        let dir = documentsDirectory.appendingPathComponent("attachments")
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    func saveAttachmentImage(image: UIImage) -> URL? {
        let maxDimension: CGFloat = 1024
        var targetSize = image.size
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let ratio = image.size.width / image.size.height
            if ratio > 1 {
                targetSize = CGSize(width: maxDimension, height: maxDimension / ratio)
            } else {
                targetSize = CGSize(width: maxDimension * ratio, height: maxDimension)
            }
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1 // Prevent automatic scaling by device screen scale
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        guard let data = resizedImage.jpegData(compressionQuality: 0.8) else { return nil }
        
        let url = attachmentsDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("Failed to save attachment image: \(error)")
            return nil
        }
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
