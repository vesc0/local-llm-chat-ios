import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Built-in markdown support in SwiftUI Text
                Text(LocalizedStringKey(message.content))
                    .padding(14)
                    .background(message.role == .user ? Theme.userBubble : Theme.assistantBubble)
                    .foregroundColor(Theme.textPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.content
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                
                if message.isStreaming {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                    }
                    .padding(.leading, 8)
                }
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}
