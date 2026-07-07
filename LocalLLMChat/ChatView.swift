import SwiftUI

struct ChatView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var inputText: String = ""
    @State private var isAtBottom: Bool = true
    @State private var forceScroll: UUID = UUID()
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }
    
    private func groupedMessages(from messages: [Message]) -> [(date: Date, messages: [Message])] {
        let grouped = Dictionary(grouping: messages) { message in
            Calendar.current.startOfDay(for: message.timestamp)
        }
        return grouped.map { (date: $0.key, messages: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if let activeConv = viewModel.activeConversation {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(groupedMessages(from: activeConv.messages), id: \.date) { group in
                                    Text(dateFormatter.string(from: group.date))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.vertical, 8)
                                    
                                    ForEach(group.messages) { message in
                                        MessageBubbleView(message: message)
                                            .id(message.id)
                                    }
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
                        .onChange(of: activeConv.messages.count) {
                            if isAtBottom {
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .onChange(of: activeConv.messages.last?.content) {
                            if isAtBottom {
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .onChange(of: forceScroll) {
                            scrollToBottom(proxy: proxy)
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                scrollToBottom(proxy: proxy)
                            }
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
