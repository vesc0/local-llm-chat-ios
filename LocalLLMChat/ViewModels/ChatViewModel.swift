import Foundation
import SwiftUI
import os

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var conversations: [Conversation]
    @Published private(set) var generatingConversationIds: Set<String> = []
    @Published private(set) var pendingAttachments: [Attachment] = []
    @Published var activeConversationId: String?
    @Published var settings: AppSettings {
        didSet { scheduleSettingsSave(changedFrom: oldValue) }
    }

    private let store: any ConversationStoring
    private let makeService: @Sendable (AppSettings) throws -> any ChatService
    private var tasks: [String: Task<Void, Never>] = [:]
    private var settingsSaveTask: Task<Void, Never>?

    init(
        store: any ConversationStoring = FileStore.shared,
        makeService: @escaping @Sendable (AppSettings) throws -> any ChatService = makeChatService
    ) {
        self.store = store
        self.makeService = makeService
        self.settings = store.loadSettings()
        self.conversations = store.loadConversations().sorted { $0.updatedAt > $1.updatedAt }
    }

    var activeConversation: Conversation? {
        conversations.first { $0.id == activeConversationId }
    }

    var isGenerating: Bool {
        activeConversationId.map(generatingConversationIds.contains) ?? false
    }

    // MARK: - Conversations

    func createConversation() {
        let conversation = Conversation(title: "New Chat", messages: [], model: settings.selectedModel)
        conversations.insert(conversation, at: 0)
        activeConversationId = conversation.id
        persist()
    }

    func deleteConversation(id: String) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        tasks.removeValue(forKey: id)?.cancel()
        generatingConversationIds.remove(id)

        let orphaned = conversations.remove(at: index).attachmentFilenames
        Task { await AttachmentStore.shared.delete(filenames: orphaned) }

        if activeConversationId == id { activeConversationId = conversations.first?.id }
        persist()
    }

    func renameConversation(id: String, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[index].title = trimmed
        persist()
    }

    // MARK: - Attachments

    func attachImage(data: Data) async {
        guard let filename = await AttachmentStore.shared.saveImage(data: data) else { return }
        pendingAttachments.append(Attachment(type: .image, filename: filename))
    }

    func attachDocument(url: URL) async {
        let extracted = await Task.detached(priority: .userInitiated) {
            DocumentExtractor.text(from: url)
        }.value
        guard let extracted else { return }
        let type: AttachmentType = url.pathExtension.lowercased() == "pdf" ? .pdf : .text
        pendingAttachments.append(Attachment(type: type, extractedText: extracted))
    }

    func removePendingAttachment(id: String) {
        guard let index = pendingAttachments.firstIndex(where: { $0.id == id }) else { return }
        let removed = pendingAttachments.remove(at: index)
        if let filename = removed.filename {
            Task { await AttachmentStore.shared.delete(filenames: [filename]) }
        }
    }

    // MARK: - Sending

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !pendingAttachments.isEmpty else { return }

        if activeConversationId == nil { createConversation() }
        guard let conversationId = activeConversationId,
              let index = conversations.firstIndex(where: { $0.id == conversationId })
        else { return }

        let attachments = pendingAttachments
        pendingAttachments = []

        conversations[index].messages.append(Message(
            role: .user,
            content: Self.prompt(trimmed, attachments: attachments),
            attachments: attachments.isEmpty ? nil : attachments
        ))
        conversations[index].updatedAt = Date()

        let isFirstExchange = conversations[index].messages.count == 1
        if isFirstExchange { conversations[index].title = Self.provisionalTitle(trimmed) }

        let assistant = Message(role: .assistant, content: "", isStreaming: true)
        let history = conversations[index].messages
        conversations[index].messages.append(assistant)

        generatingConversationIds.insert(conversationId)
        persist()

        tasks[conversationId] = Task { [settings] in
            await respond(
                to: history,
                conversationId: conversationId,
                messageId: assistant.id,
                settings: settings,
                titleAfterwards: isFirstExchange
            )
        }
    }

    /// Cancels the named conversation's generation, or the active one.
    func stop(conversationId: String? = nil) {
        guard let id = conversationId ?? activeConversationId else { return }
        tasks[id]?.cancel()
    }

    private func respond(
        to history: [Message],
        conversationId: String,
        messageId: String,
        settings: AppSettings,
        titleAfterwards: Bool
    ) async {
        do {
            let service = try makeService(settings)
            for try await token in service.stream(history) {
                append(token, to: messageId, in: conversationId)
            }
            try Task.checkCancellation()
            update(messageId, in: conversationId) { $0.isStreaming = false }
            if titleAfterwards { await retitle(conversationId, using: service) }
        } catch {
            let cancelled = error is CancellationError || (error as? URLError)?.code == .cancelled
            update(messageId, in: conversationId) { message in
                message.isStreaming = false
                if cancelled { message.isCancelled = true }
                else { message.errorMessage = Self.describe(error) }
            }
        }

        generatingConversationIds.remove(conversationId)
        tasks[conversationId] = nil
        persist()
    }

    private func retitle(_ conversationId: String, using service: any ChatService) async {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        let request = conversations[index].messages + [Message(
            role: .user,
            content: "Summarize our conversation above into a title of at most 5 words. "
                + "Reply with the title only — no quotes, prefixes or punctuation."
        )]

        do {
            let title = try await service.generate(request)
                .replacingOccurrences(of: "\"", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty,
                  let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            conversations[index].title = String(title.prefix(60))
        } catch {
            Logger.app.notice("Title generation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Message updates

    private func update(_ messageId: String, in conversationId: String, _ body: (inout Message) -> Void) {
        guard let conversation = conversations.firstIndex(where: { $0.id == conversationId }),
              let message = conversations[conversation].messages.firstIndex(where: { $0.id == messageId })
        else { return }
        body(&conversations[conversation].messages[message])
    }

    private static let thoughtOpeners = ["<think", "<thought", "<|begin_of_thought|>"]
    private static let thoughtClosers = ["</think>", "</thought>", "<|end_of_thought|>"]

    private func append(_ token: String, to messageId: String, in conversationId: String) {
        update(messageId, in: conversationId) { message in
            message.content += token
            // Scanning is bounded to the thinking phase of a reasoning model's reply.
            guard message.thoughtTime == nil,
                  Self.thoughtOpeners.contains(where: message.content.hasPrefix),
                  Self.thoughtClosers.contains(where: message.content.contains)
            else { return }
            message.thoughtTime = Date().timeIntervalSince(message.timestamp)
        }
    }

    // MARK: - Persistence

    private func persist() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
        let snapshot = conversations
        Task { await store.save(conversations: snapshot) }
    }

    private func scheduleSettingsSave(changedFrom oldValue: AppSettings) {
        guard settings != oldValue else { return }
        settingsSaveTask?.cancel()
        settingsSaveTask = Task { [settings, store] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await store.save(settings: settings)
        }
    }

    // MARK: - Formatting

    private static func prompt(_ text: String, attachments: [Attachment]) -> String {
        let documents = attachments.compactMap(\.extractedText)
        guard !documents.isEmpty else { return text }
        let body = documents.joined(separator: "\n\n---\n\n")
        return text.isEmpty
            ? "Here are the attached documents:\n\n\(body)"
            : "\(text)\n\nAttached documents:\n\n\(body)"
    }

    private static func provisionalTitle(_ text: String) -> String {
        let title = text.isEmpty ? "New Chat" : text
        return title.count > 30 ? String(title.prefix(30)) + "…" : title
    }

    private static func describe(_ error: any Error) -> String {
        guard error is URLError else { return error.localizedDescription }
        return "\(error.localizedDescription)\n\nCheck the Ollama host in Settings, "
            + "and that Local Network access is allowed for this app."
    }
}
