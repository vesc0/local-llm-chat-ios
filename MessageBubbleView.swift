import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    private var bubbleTextColor: Color {
        message.role == .user ? .white : Theme.textPrimary
    }
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.isStreaming && message.content.isEmpty {
                        TypingIndicatorView()
                            .padding(14)
                            .frame(minHeight: 44)
                    } else if !message.content.isEmpty || message.isCancelled || message.errorMessage != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            if !message.content.isEmpty {
                                Text(LocalizedStringKey(message.content))
                                    .foregroundColor(bubbleTextColor)
                            }
                            if message.isCancelled {
                                Text("(cancelled)")
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                            }
                            if let error = message.errorMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.subheadline)
                            }
                        }
                        .padding(14)
                    }
                }
                .background(message.role == .user ? Theme.userBubble : Theme.assistantBubble)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .contextMenu {
                    if !message.content.isEmpty {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}

struct TypingIndicatorView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Theme.textPrimary)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0), value: isAnimating)
            
            Circle()
                .fill(Theme.textPrimary)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: isAnimating)
            
            Circle()
                .fill(Theme.textPrimary)
                .frame(width: 6, height: 6)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .opacity(isAnimating ? 1.0 : 0.3)
                .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: isAnimating)
        }
        .onAppear {
            isAnimating = true
        }
    }
}
