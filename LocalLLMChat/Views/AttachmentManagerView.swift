import SwiftUI

struct AttachmentManagerView: View {
    @State private var images: [URL] = []
    @State private var preview: PreviewedImage?

    var body: some View {
        List {
            if images.isEmpty {
                ContentUnavailableView("No Images", systemImage: "photo.on.rectangle")
            } else {
                ForEach(images, id: \.self) { url in
                    Button { preview = PreviewedImage(url: url) } label: { row(url) }
                        .foregroundStyle(.primary)
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Uploaded Images")
        .task { await load() }
        .sheet(item: $preview) { item in
            NavigationStack {
                ImagePreview(url: item.url) {
                    Task {
                        await AttachmentStore.shared.delete(filenames: [item.url.lastPathComponent])
                        preview = nil
                        await load()
                    }
                }
            }
        }
    }

    private func row(_ url: URL) -> some View {
        HStack {
            AttachmentImage(filename: url.lastPathComponent, size: 60)
            VStack(alignment: .leading) {
                Text(url.lastPathComponent).font(.subheadline).lineLimit(1)
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attributes[.size] as? Int64,
                   let date = attributes[.creationDate] as? Date {
                    Text("\(ByteCountFormatter.file.string(fromByteCount: size)) • \(date, style: .date)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func delete(_ offsets: IndexSet) {
        let filenames = offsets.map { images[$0].lastPathComponent }
        images.remove(atOffsets: offsets)
        Task { await AttachmentStore.shared.delete(filenames: filenames) }
    }

    private func load() async {
        images = await AttachmentStore.shared.listImages()
    }
}

private struct ImagePreview: View {
    let url: URL
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().padding()
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Image")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .tint(.red)
            }
        }
        .task {
            image = await Task.detached(priority: .userInitiated) {
                UIImage(contentsOfFile: url.path)
            }.value
        }
    }
}

private struct PreviewedImage: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
