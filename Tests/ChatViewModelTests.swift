import XCTest
@testable import LocalLLMChat

@MainActor
final class ChatViewModelTests: XCTestCase {
    private func makeViewModel(
        _ service: StubChatService,
        store: MemoryStore = MemoryStore()
    ) -> ChatViewModel {
        ChatViewModel(store: store, makeService: { _ in service })
    }

    private func idle(_ viewModel: ChatViewModel) async {
        await waitUntil { viewModel.generatingConversationIds.isEmpty }
    }

    func testStreamedTokensLandInTheAssistantMessage() async {
        let viewModel = makeViewModel(StubChatService(tokens: ["Hel", "lo"]))
        viewModel.send("Hi")
        await idle(viewModel)

        let messages = try? XCTUnwrap(viewModel.activeConversation).messages
        XCTAssertEqual(messages?.count, 2)
        XCTAssertEqual(messages?.first?.role, .user)
        XCTAssertEqual(messages?.last?.content, "Hello")
        XCTAssertEqual(messages?.last?.isStreaming, false)
    }

    func testFirstExchangeIsRetitled() async {
        let viewModel = makeViewModel(StubChatService(tokens: ["Greeting"]))
        viewModel.send("Hi")
        await idle(viewModel)

        XCTAssertEqual(viewModel.activeConversation?.title, "Greeting")
    }

    func testFailureIsReportedOnTheMessage() async {
        let viewModel = makeViewModel(StubChatService(failure: .boom))
        viewModel.send("Hi")
        await idle(viewModel)

        let last = viewModel.activeConversation?.messages.last
        XCTAssertNotNil(last?.errorMessage)
        XCTAssertEqual(last?.isStreaming, false)
    }

    func testEmptyInputIsIgnored() {
        let viewModel = makeViewModel(StubChatService())
        viewModel.send("   ")
        XCTAssertTrue(viewModel.conversations.isEmpty)
    }

    func testDeletingAConversationClearsTheSelection() async {
        let viewModel = makeViewModel(StubChatService(tokens: ["ok"]))
        viewModel.send("Hi")
        await idle(viewModel)

        let id = try? XCTUnwrap(viewModel.activeConversationId)
        viewModel.deleteConversation(id: id ?? "")

        XCTAssertTrue(viewModel.conversations.isEmpty)
        XCTAssertNil(viewModel.activeConversationId)
    }

    func testConversationsPersistAfterAnExchange() async {
        let store = MemoryStore()
        let viewModel = makeViewModel(StubChatService(tokens: ["ok"]), store: store)
        viewModel.send("Hi")
        await idle(viewModel)
        await waitUntil { store.conversations.first?.messages.count == 2 }

        XCTAssertEqual(store.conversations.count, 1)
    }

    func testRenameIgnoresBlankTitles() async {
        let viewModel = makeViewModel(StubChatService())
        viewModel.createConversation()
        let id = viewModel.activeConversationId ?? ""

        viewModel.renameConversation(id: id, to: "  ")
        XCTAssertEqual(viewModel.activeConversation?.title, "New Chat")

        viewModel.renameConversation(id: id, to: " Renamed ")
        XCTAssertEqual(viewModel.activeConversation?.title, "Renamed")
    }
}
