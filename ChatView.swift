import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var isAtBottom: Bool = true
    @State private var forceScroll: UUID = UUID()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let activeConv = viewModel.activeConversation {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(activeConv.messages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                }
                                
                                // Invisible bottom anchor used for scroll tracking and programmatic scrolling
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                                    .onAppear { isAtBottom = true }
                                    .onDisappear { isAtBottom = false }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .onChange(of: activeConv.messages.count) { _ in
                            if isAtBottom {
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .onChange(of: activeConv.messages.last?.content) { _ in
                            if isAtBottom {
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .onChange(of: forceScroll) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
                
                ChatInputView(inputText: $inputText)
            }
            
            if !isAtBottom {
                Button(action: {
                    forceScroll = UUID()
                }) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white))
                        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                }
                .padding(.bottom, 70)
                .transition(.opacity.combined(with: .scale))
                .animation(.easeInOut(duration: 0.2), value: isAtBottom)
            }
        }
        .navigationTitle(viewModel.activeConversation?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}
