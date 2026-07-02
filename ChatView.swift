import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if let activeConv = viewModel.activeConversation {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(activeConv.messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .onChange(of: activeConv.messages.count) { _ in
                        scrollToBottom(proxy: proxy, messages: activeConv.messages)
                    }
                    .onChange(of: activeConv.messages.last?.content) { _ in
                        scrollToBottom(proxy: proxy, messages: activeConv.messages)
                    }
                }
            }
            
            Divider()
            ChatInputView(inputText: $inputText)
        }
        .navigationTitle(viewModel.activeConversation?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy, messages: [Message]) {
        guard let last = messages.last else { return }
        withAnimation {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
