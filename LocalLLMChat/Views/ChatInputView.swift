import SwiftUI
import PhotosUI

struct ChatInputView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @Binding var inputText: String

    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !viewModel.pendingAttachments.isEmpty
    }

    var body: some View {
        VStack(spacing: 10) {
            if !viewModel.pendingAttachments.isEmpty { pendingRow }

            HStack(alignment: .bottom, spacing: 8) {
                attachMenu
                composer
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 10)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf, .plainText, .commaSeparatedText]
        ) { result in
            guard case .success(let url) = result else { return }
            Task { await viewModel.attachDocument(url: url) }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await viewModel.attachImage(data: data)
                }
                photoItem = nil
            }
        }
    }

    private var pendingRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.pendingAttachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        switch attachment.type {
                        case .image:
                            if let filename = attachment.filename {
                                AttachmentImage(filename: filename, size: 60)
                            }
                        case .pdf:
                            DocumentThumbnail(icon: "doc.text.fill", color: .red)
                        case .text:
                            DocumentThumbnail(icon: "doc.plaintext.fill", color: .gray)
                        }

                        Button {
                            viewModel.removePendingAttachment(id: attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white, .black.opacity(0.7))
                        }
                        .accessibilityLabel("Remove attachment")
                        .offset(x: 8, y: -8)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var attachMenu: some View {
        Menu {
            Button("Photo Library", systemImage: "photo") { showPhotoPicker = true }
            Button("Choose File", systemImage: "doc") { showDocumentPicker = true }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: .circle)
        }
        .accessibilityLabel("Add attachment")
        .padding(.bottom, 2)
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 4) {
            TextField("Type a message…", text: $inputText, axis: .vertical)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .lineLimit(1...5)

            if viewModel.isGenerating {
                circleButton("stop.fill", background: Color(.label), foreground: Color(.systemBackground)) {
                    viewModel.stop()
                }
                .accessibilityLabel("Stop generating")
            } else {
                circleButton("arrow.up", background: canSend ? Theme.accent : Color(.systemGray3), foreground: .white) {
                    let text = inputText
                    inputText = ""
                    viewModel.send(text)
                }
                .accessibilityLabel("Send message")
                .disabled(!canSend)
            }
        }
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
    }

    private func circleButton(
        _ symbol: String,
        background: Color,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(foreground)
                .frame(width: 32, height: 32)
                .background(background, in: .circle)
        }
        .padding([.trailing, .bottom], 4)
    }
}
