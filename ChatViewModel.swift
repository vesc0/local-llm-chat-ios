import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var activeConversationId: String? = nil
    @Published var generatingConversationIds: Set<String> = []
    @Published var settings: AppSettings = AppSettings()
    
    private var streamingTasks: [String: Task<Void, Never>] = [:]
    
    var isGenerating: Bool {
        guard let id = activeConversationId else { return false }
        return generatingConversationIds.contains(id)
    }
    
    init() {
        self.conversations = StorageService.shared.loadConversations()
        self.settings = StorageService.shared.loadSettings()
        
        if let first = self.conversations.first {
            self.activeConversationId = first.id
        }
    }
    
    var activeConversation: Conversation? {
        conversations.first { $0.id == activeConversationId }
    }
    
    func createConversation() {
        let newConv = Conversation(title: "New Chat", messages: [], model: settings.selectedModel)
        conversations.insert(newConv, at: 0)
        activeConversationId = newConv.id
        save()
    }
    
    func deleteConversation(id: String) {
        conversations.removeAll { $0.id == id }
        if activeConversationId == id {
            activeConversationId = conversations.first?.id
        }
        save()
    }
    
    func renameConversation(id: String, newTitle: String) {
        if let index = conversations.firstIndex(where: { $0.id == id }) {
            conversations[index].title = newTitle
            save()
        }
    }
    
    func sendMessage(_ content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if activeConversationId == nil {
            createConversation()
        }
        
        guard let id = activeConversationId, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        
        let userMessage = Message(role: .user, content: content)
        conversations[index].messages.append(userMessage)
        
        // Auto-title if it's the first message
        let isFirstMessage = conversations[index].messages.count == 1
        if isFirstMessage {
            let title = String(content.prefix(30)) + (content.count > 30 ? "..." : "")
            conversations[index].title = title
        }
        
        let assistantMessage = Message(role: .assistant, content: "", isStreaming: true)
        conversations[index].messages.append(assistantMessage)
        
        generatingConversationIds.insert(id)
        save()
        
        let messagesToSent = conversations[index].messages.dropLast() // exclude the empty assistant message
        
        let task = Task {
            do {
                try await OllamaService.shared.streamChat(messages: Array(messagesToSent), settings: settings) { [weak self] token in
                    guard let self = self else { return }
                    if let convIndex = self.conversations.firstIndex(where: { $0.id == id }) {
                        let msgCount = self.conversations[convIndex].messages.count
                        if msgCount > 0 {
                            self.conversations[convIndex].messages[msgCount - 1].content += token
                        }
                    }
                }
                
                // Done
                if let convIndex = self.conversations.firstIndex(where: { $0.id == id }) {
                    let msgCount = self.conversations[convIndex].messages.count
                    if msgCount > 0 {
                        self.conversations[convIndex].messages[msgCount - 1].isStreaming = false
                    }
                }
                
                if isFirstMessage {
                    await self.generateTitle(for: id)
                }
            } catch {
                if let convIndex = self.conversations.firstIndex(where: { $0.id == id }) {
                    let msgCount = self.conversations[convIndex].messages.count
                    if msgCount > 0 {
                        self.conversations[convIndex].messages[msgCount - 1].content += "\n\n**Error**: \(error.localizedDescription)"
                        self.conversations[convIndex].messages[msgCount - 1].isStreaming = false
                    }
                }
            }
            
            self.generatingConversationIds.remove(id)
            self.streamingTasks.removeValue(forKey: id)
            self.save()
        }
        
        streamingTasks[id] = task
    }
    
    private func generateTitle(for conversationId: String) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        var messagesForTitle = conversations[index].messages
        // System prompt to ask for a concise title
        let promptMessage = Message(role: .user, content: "Summarize our conversation above into a very concise title (maximum 5 words). Reply ONLY with the title text itself, without quotes, prefixes, or punctuation.")
        messagesForTitle.append(promptMessage)
        
        do {
            let generatedTitle = try await OllamaService.shared.generateChat(messages: messagesForTitle, settings: settings)
            if !generatedTitle.isEmpty {
                // Remove quotes if the LLM happened to include them
                let cleanTitle = generatedTitle.replacingOccurrences(of: "\"", with: "")
                if let currentIndex = self.conversations.firstIndex(where: { $0.id == conversationId }) {
                    self.conversations[currentIndex].title = cleanTitle
                }
            }
        } catch {
            print("Failed to generate title: \(error)")
        }
    }
    
    func stopGeneration() {
        guard let id = activeConversationId else { return }
        streamingTasks[id]?.cancel()
        streamingTasks.removeValue(forKey: id)
        generatingConversationIds.remove(id)
        
        if let convIndex = conversations.firstIndex(where: { $0.id == id }) {
            let msgCount = conversations[convIndex].messages.count
            if msgCount > 0 {
                conversations[convIndex].messages[msgCount - 1].isStreaming = false
            }
        }
        save()
    }
    
    func saveSettings() {
        StorageService.shared.saveSettings(settings)
    }
    
    private func save() {
        StorageService.shared.saveConversations(conversations)
    }
}
