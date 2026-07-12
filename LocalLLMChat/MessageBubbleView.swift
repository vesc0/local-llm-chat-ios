import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    @State private var isCopied = false
    
    private var isUser: Bool {
        message.role == .user
    }
    
    private var bubbleTextColor: Color {
        isUser ? .white : Theme.textPrimary
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                // Assistant Avatar
                ZStack {
                    Circle()
                        .fill(Theme.textPrimary.opacity(0.1))
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                }
                .frame(width: 28, height: 28)
                .padding(.top, isUser ? 0 : 2)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Group {
                    if message.isStreaming && message.content.isEmpty {
                        TypingIndicatorView()
                            .padding(isUser ? 14 : 0)
                            .padding(.vertical, isUser ? 0 : 10)
                            .frame(minHeight: isUser ? 44 : 20)
                    } else if !message.content.isEmpty || message.isCancelled || message.errorMessage != nil || (message.attachments != nil && !message.attachments!.isEmpty) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let attachments = message.attachments, !attachments.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(attachments) { attachment in
                                            if attachment.type == .image, let url = attachment.url, let uiImage = UIImage(contentsOfFile: url.path) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 150, height: 150)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                            } else if attachment.type == .pdf {
                                                DocumentThumbnail(icon: "doc.text.fill", color: .red)
                                                    .frame(width: 80, height: 80)
                                            } else if attachment.type == .text {
                                                DocumentThumbnail(icon: "doc.plaintext.fill", color: .gray)
                                                    .frame(width: 80, height: 80)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if !message.content.isEmpty {
                                Text(LocalizedStringKey(message.content))
                                    .foregroundColor(bubbleTextColor)
                                    .textSelection(.enabled)
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
                        .padding(isUser ? 14 : 0)
                        .padding(.vertical, isUser ? 0 : 4)
                    }
                }
                .background(isUser ? Theme.userBubble : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: isUser ? 18 : 0))
                
                if !message.isStreaming || !message.content.isEmpty {
                    HStack(spacing: 12) {
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if !isUser {
                            Button {
                                UIPasteboard.general.string = message.content
                                withAnimation {
                                    isCopied = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation {
                                        isCopied = false
                                    }
                                }
                            } label: {
                                if isCopied {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark")
                                        Text("Copied")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.green)
                                } else {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, isUser ? 4 : 0)
                    .padding(.top, 2)
                }
            }
            
            if !isUser {
                Spacer(minLength: 0)
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
