import SwiftUI

struct MessageBubbleView: View {
    let message: Message

    @State private var isCopied = false
    @State private var isThoughtExpanded = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser {
                Spacer(minLength: 40)
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .background(.primary.opacity(0.1), in: .circle)
                    .accessibilityHidden(true)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                bubble
                    .background(isUser ? Theme.userBubble : .clear)
                    .clipShape(.rect(cornerRadius: isUser ? 18 : 0))
                footer
            }

            if !isUser { Spacer(minLength: 0) }
        }
    }

    @ViewBuilder
    private var bubble: some View {
        if message.isStreaming && message.content.isEmpty {
            TypingIndicator()
                .padding(.vertical, 10)
                .accessibilityLabel("Generating response")
        } else {
            let parsed = ThoughtParser.parse(message.content)

            VStack(alignment: .leading, spacing: 8) {
                if let attachments = message.attachments, !attachments.isEmpty {
                    AttachmentStrip(attachments: attachments)
                }
                if let thought = parsed.thought {
                    thoughtSection(thought, hasAnswer: !parsed.answer.isEmpty)
                }
                if !parsed.answer.isEmpty {
                    MarkdownText(text: parsed.answer)
                        .foregroundStyle(isUser ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                }
                if message.isCancelled {
                    Text("(cancelled)").font(.subheadline).foregroundStyle(.red)
                }
                if let error = message.errorMessage {
                    Text(error).font(.subheadline).foregroundStyle(.red)
                }
            }
            .padding(isUser ? 14 : 0)
            .padding(.vertical, isUser ? 0 : 4)
        }
    }

    private func thoughtSection(_ thought: String, hasAnswer: Bool) -> some View {
        DisclosureGroup(isExpanded: $isThoughtExpanded) {
            Text(thought)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                if message.isStreaming && !hasAnswer {
                    ThinkingLabel()
                } else if let seconds = message.thoughtTime {
                    Text("Thought for \(seconds, format: .number.precision(.fractionLength(1)))s")
                } else {
                    Text("Thought Process")
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(.secondary.opacity(0.1), in: .rect(cornerRadius: 8))
        .padding(.bottom, hasAnswer ? 8 : 0)
    }

    @ViewBuilder
    private var footer: some View {
        if !message.isStreaming || !message.content.isEmpty {
            HStack(spacing: 12) {
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                if !isUser {
                    Button(action: copy) {
                        Group {
                            if isCopied {
                                Label("Copied", systemImage: "checkmark").labelStyle(.titleAndIcon)
                            } else {
                                Label("Copy", systemImage: "doc.on.doc").labelStyle(.iconOnly)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(isCopied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy message")
                }
            }
            .padding(.horizontal, isUser ? 4 : 0)
            .padding(.top, 2)
        }
    }

    private func copy() {
        UIPasteboard.general.string = ThoughtParser.parse(message.content).answer
        withAnimation { isCopied = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { isCopied = false }
        }
    }
}

// MARK: - Thought parsing

enum ThoughtParser {
    struct Result {
        let thought: String?
        let answer: String
    }

    private static let regex = try? NSRegularExpression(
        pattern: #"(?i)<(?:think|thought|\|begin_of_thought\|)>([\s\S]*?)(?:</(?:think|thought)>|<\|end_of_thought\|>|$)"#
    )

    /// Splits a reply into its reasoning trace and its answer.
    static func parse(_ content: String) -> Result {
        guard let regex else { return Result(thought: nil, answer: content) }

        let full = content as NSString
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: full.length))
        guard !matches.isEmpty else { return Result(thought: nil, answer: content) }

        let thoughts = matches
            .map { full.substring(with: $0.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var answer = content
        for match in matches.reversed() {
            answer = (answer as NSString).replacingCharacters(in: match.range, with: "")
        }

        return Result(
            thought: thoughts.isEmpty ? nil : thoughts.joined(separator: "\n\n"),
            answer: answer.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

// MARK: - Attachments

private struct AttachmentStrip: View {
    let attachments: [Attachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    switch attachment.type {
                    case .image:
                        if let filename = attachment.filename {
                            AttachmentImage(filename: filename, size: 150)
                        }
                    case .pdf:
                        DocumentThumbnail(icon: "doc.text.fill", color: .red).frame(width: 80, height: 80)
                    case .text:
                        DocumentThumbnail(icon: "doc.plaintext.fill", color: .gray).frame(width: 80, height: 80)
                    }
                }
            }
        }
    }
}

struct AttachmentImage: View {
    let filename: String
    let size: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Theme.surface
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: 8))
        .task {
            let url = AttachmentStore.shared.url(for: filename)
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)
            }.value
        }
        .accessibilityLabel("Attached image")
    }
}

struct DocumentThumbnail: View {
    let icon: String
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Theme.surface)
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(color)
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: - Activity indicators

private struct TypingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear { isAnimating = true }
    }
}

private struct ThinkingLabel: View {
    @State private var isGlowing = false

    var body: some View {
        HStack(spacing: 4) {
            Text("Thinking")
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.secondary)
                        .frame(width: 3, height: 3)
                        .opacity(isGlowing ? 1 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6).repeatForever().delay(Double(index) * 0.2),
                            value: isGlowing
                        )
                }
            }
            .offset(y: 4)
        }
        .opacity(isGlowing ? 1 : 0.7)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isGlowing)
        .onAppear { isGlowing = true }
    }
}
