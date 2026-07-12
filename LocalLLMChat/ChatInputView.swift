import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatInputView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var inputText: String
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !viewModel.pendingAttachments.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 10) {
            // Pending attachments row
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            ZStack(alignment: .topTrailing) {
                                Group {
                                    if attachment.type == .image, let url = attachment.url, let uiImage = UIImage(contentsOfFile: url.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else if attachment.type == .pdf {
                                        DocumentThumbnail(icon: "doc.text.fill", color: .red)
                                    } else {
                                        DocumentThumbnail(icon: "doc.plaintext.fill", color: .gray)
                                    }
                                }
                                
                                Button(action: {
                                    viewModel.removePendingAttachment(id: attachment.id)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .background(Circle().fill(Color.black.opacity(0.7)))
                                }
                                .offset(x: 8, y: -8)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // Input row: + button, unified text field & send button pill
            HStack(alignment: .bottom, spacing: 8) {
                // Plus button — glass circle
                Menu {
                    Button(action: {
                        showPhotoPicker = true
                    }) {
                        Label("Photo Library", systemImage: "photo")
                    }
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        Label("Choose File", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding(.bottom, 2)
                
                // Unified glass pill for text field and send button
                HStack(alignment: .bottom, spacing: 4) {
                    TextField("Type a message...", text: $inputText, axis: .vertical)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .lineLimit(1...5)
                    
                    // Send / Stop button inside the pill
                    if viewModel.isGenerating {
                        Button(action: {
                            viewModel.stopGeneration()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color(UIColor.label))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(UIColor.systemBackground))
                            }
                        }
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                    } else {
                        Button(action: {
                            let text = inputText
                            inputText = ""
                            viewModel.sendMessage(text)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(canSend ? Theme.accent : Color(UIColor.systemGray3))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .disabled(!canSend)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .padding(.top, 10)
        .fileImporter(isPresented: $showDocumentPicker, allowedContentTypes: [.pdf, .plainText, .commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                viewModel.addDocumentAttachment(url: url)
            case .failure(let error):
                print("Failed to select document: \(error)")
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            guard let item = newValue else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            viewModel.addImageAttachment(image)
                        }
                    } else {
                        print("Failed to convert picked photo to UIImage")
                    }
                } catch {
                    print("Error loading photo: \(error)")
                }
                
                await MainActor.run {
                    selectedPhotoItem = nil
                }
            }
        }
    }
}

struct DocumentThumbnail: View {
    let icon: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Theme.surface)
                .frame(width: 60, height: 60)
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
        }
    }
}
