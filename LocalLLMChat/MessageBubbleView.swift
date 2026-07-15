import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    @State private var isCopied = false
    @State private var isThoughtExpanded = false
    
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
                                let parsed = parseMessage(message.content)
                                
                                if let thought = parsed.thought {
                                    DisclosureGroup(isExpanded: $isThoughtExpanded) {
                                        Text(LocalizedStringKey(thought))
                                            .font(.callout)
                                            .foregroundColor(.secondary)
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "brain")
                                            if message.isStreaming && parsed.answer.isEmpty {
                                                AnimatedThinkingLabel()
                                            } else if let thoughtTime = message.thoughtTime {
                                                Text("Thought for \(String(format: "%.1f", thoughtTime))s")
                                            } else {
                                                Text("Thought Process")
                                            }
                                        }
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 10)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .padding(.bottom, parsed.answer.isEmpty ? 0 : 8)
                                }
                                
                                if !parsed.answer.isEmpty {
                                    Text(LocalizedStringKey(parsed.answer))
                                        .foregroundColor(bubbleTextColor)
                                        .textSelection(.enabled)
                                }
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
    
    private struct ParsedMessage {
        var thought: String?
        var answer: String
    }
    
    private func parseMessage(_ content: String) -> ParsedMessage {
        var thoughts: [String] = []
        var answer = content
        
        let pattern = "(?i)<(?:think|thought|\\|begin_of_thought\\|)>([\\s\\S]*?)(?:</(?:think|thought)>|<\\|end_of_thought\\|>|$)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let nsString = answer as NSString
            let results = regex.matches(in: answer, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in results.reversed() {
                if match.numberOfRanges > 1 {
                    let thoughtRange = match.range(at: 1)
                    if thoughtRange.location != NSNotFound {
                        let thought = nsString.substring(with: thoughtRange).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !thought.isEmpty {
                            thoughts.insert(thought, at: 0)
                        }
                    }
                    
                    let fullMatchRange = match.range(at: 0)
                    answer = (answer as NSString).replacingCharacters(in: fullMatchRange, with: "")
                }
            }
        }
        
        let finalThought = thoughts.isEmpty ? nil : thoughts.joined(separator: "\n\n")
        let finalAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return ParsedMessage(thought: finalThought, answer: finalAnswer)
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

struct AnimatedThinkingLabel: View {
    @State private var isGlowing = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Thinking")
            
            HStack(spacing: 2) {
                Circle().fill(Color.secondary).frame(width: 3, height: 3)
                    .opacity(isGlowing ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(0), value: isGlowing)
                Circle().fill(Color.secondary).frame(width: 3, height: 3)
                    .opacity(isGlowing ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.2), value: isGlowing)
                Circle().fill(Color.secondary).frame(width: 3, height: 3)
                    .opacity(isGlowing ? 1 : 0.3)
                    .animation(.easeInOut(duration: 0.6).repeatForever().delay(0.4), value: isGlowing)
            }
            .offset(y: 4) // Align dots with the baseline
        }
        .shadow(color: isGlowing ? Color.primary.opacity(0.4) : Color.clear, radius: isGlowing ? 4 : 0)
        .opacity(isGlowing ? 1.0 : 0.7)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isGlowing)
        .onAppear {
            isGlowing = true
        }
    }
}
