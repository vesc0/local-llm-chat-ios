import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @State private var inputText = ""
    @State private var bottomY: CGFloat = 0
    @State private var scrollTrigger = 0
    @State private var viewportHeight: CGFloat = 0

    /// Derived from both measurements so neither preference has to arrive first.
    private var isAtBottom: Bool { bottomY <= viewportHeight + 50 }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            if let conversation = viewModel.activeConversation {
                transcript(conversation)
            }

            if !isAtBottom {
                Button { scrollTrigger += 1 } label: {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: .circle)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .accessibilityLabel("Scroll to latest message")
                .padding(.bottom, 60)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isAtBottom)
        .navigationTitle(viewModel.activeConversation?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func transcript(_ conversation: Conversation) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Self.groupedByDay(conversation.messages), id: \.day) { group in
                        Text(Self.dayFormatter.string(from: group.day))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)

                        ForEach(group.messages) { message in
                            MessageBubbleView(message: message).id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.bottomAnchor)
                        .background(GeometryReader { geometry in
                            Color.clear.preference(
                                key: BottomAnchorKey.self,
                                value: geometry.frame(in: .named(Self.space)).maxY
                            )
                        })
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .coordinateSpace(name: Self.space)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: ViewportHeightKey.self, value: geometry.size.height)
            })
            .onPreferenceChange(ViewportHeightKey.self) { viewportHeight = $0 }
            .onPreferenceChange(BottomAnchorKey.self) { bottomY = $0 }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) { ChatInputView(inputText: $inputText) }
            .onChange(of: conversation.messages.count) { scrollToBottom(proxy, force: false) }
            .onChange(of: conversation.messages.last?.content) { scrollToBottom(proxy, force: false) }
            .onChange(of: scrollTrigger) { scrollToBottom(proxy, force: true) }
            .onAppear { proxy.scrollTo(Self.bottomAnchor, anchor: .bottom) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, force: Bool) {
        guard force || isAtBottom else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(Self.bottomAnchor, anchor: .bottom)
        }
    }

    private static let space = "transcript"
    private static let bottomAnchor = "bottom"

    /// Messages arrive in order, so a single pass beats grouping and re-sorting.
    private static func groupedByDay(_ messages: [Message]) -> [(day: Date, messages: [Message])] {
        messages.reduce(into: []) { groups, message in
            let day = Calendar.current.startOfDay(for: message.timestamp)
            if groups.last?.day == day {
                groups[groups.count - 1].messages.append(message)
            } else {
                groups.append((day, [message]))
            }
        }
    }
}

private struct BottomAnchorKey: PreferenceKey {
    static let defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = min(value, nextValue())
    }
}

private struct ViewportHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
