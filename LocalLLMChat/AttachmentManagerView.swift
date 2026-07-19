import SwiftUI

struct ImageItem: Identifiable {
    let id: URL
    var url: URL { id }
}

struct AttachmentManagerView: View {
    @State private var imageURLs: [URL] = []
    @State private var selectedImage: ImageItem? = nil

    var body: some View {
        List {
            if imageURLs.isEmpty {
                Text("No uploaded images found.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(imageURLs, id: \.self) { url in
                    Button(action: { selectedImage = ImageItem(id: url) }) {
                        HStack {
                            if let uiImage = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                            }
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                                   let size = attributes[.size] as? Int64,
                                   let date = attributes[.creationDate] as? Date {
                                    Text("\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) • \(date, style: .date)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let url = imageURLs[index]
                        StorageService.shared.deleteAttachment(at: url)
                    }
                    loadImages()
                }
            }
        }
        .navigationTitle("Uploaded Images")
        .onAppear {
            loadImages()
        }
        .sheet(item: $selectedImage) { item in
            NavigationView {
                AttachmentDetailView(url: item.url) {
                    StorageService.shared.deleteAttachment(at: item.url)
                    loadImages()
                    selectedImage = nil
                }
            }
        }
    }

    private func loadImages() {
        imageURLs = StorageService.shared.listAttachmentImages()
    }
}

struct AttachmentDetailView: View {
    let url: URL
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            if let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            } else {
                Text("Image not found")
            }
        }
        .navigationTitle("View Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .destructive, action: {
                    onDelete()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
}
