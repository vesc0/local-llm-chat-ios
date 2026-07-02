import SwiftUI

struct ChatInputView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var inputText: String
    
    var body: some View {
        HStack(alignment: .bottom) {
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .padding(12)
                .background(Theme.surface)
                .cornerRadius(20)
                .lineLimit(1...5)
            
            if viewModel.isGenerating {
                Button(action: {
                    viewModel.stopGeneration()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(Theme.textPrimary)
                }
                .padding(.bottom, 4)
            } else {
                Button(action: {
                    let text = inputText
                    inputText = ""
                    viewModel.sendMessage(text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textSecondary : Theme.accent)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .padding(.bottom, 4)
            }
        }
        .padding()
        .background(Theme.background)
    }
}
