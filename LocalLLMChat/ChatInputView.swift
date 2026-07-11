import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatInputView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @Binding var inputText: String
    
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    
    var body: some View {
        VStack(spacing: 8) {
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
                    .padding(.horizontal)
                }
            }
            
            HStack(alignment: .bottom) {
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
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.bottom, 8)
                        .padding(.trailing, 4)
                }
                
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
                            .foregroundColor((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty) ? Theme.textSecondary : Theme.accent)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty)
                    .padding(.bottom, 4)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Theme.background)
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
