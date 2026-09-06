import Foundation
import UIKit
import os

/// Owns the on-disk attachment images. Paths are resolved from the filename on
/// every access because the sandbox container UUID changes between launches.
actor AttachmentStore {
    static let shared = AttachmentStore()

    private static let maxDimension: CGFloat = 1024
    private var base64Cache: [String: String] = [:]

    nonisolated func url(for filename: String) -> URL {
        Self.directory.appending(path: filename)
    }

    private static var directory: URL {
        let dir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "attachments")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Downsizes and stores a picked image, returning its filename.
    func saveImage(data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        guard let jpeg = Self.downsized(image).jpegData(compressionQuality: 0.8) else { return nil }

        let filename = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: url(for: filename), options: .atomic)
            return filename
        } catch {
            Logger.app.error("Failed to save attachment: \(error)")
            return nil
        }
    }

    /// Base64 payloads for Ollama, cached because the whole history is re-sent each turn.
    func base64Images(for attachments: [Attachment]) -> [String] {
        attachments.compactMap { attachment in
            guard attachment.type == .image, let filename = attachment.filename else { return nil }
            if let cached = base64Cache[filename] { return cached }
            guard let data = try? Data(contentsOf: url(for: filename)) else { return nil }
            let encoded = data.base64EncodedString()
            base64Cache[filename] = encoded
            return encoded
        }
    }

    func listImages() -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: Self.directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        return contents
            .filter { ["jpg", "png"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.creationDate > $1.creationDate }
    }

    func delete(filenames: [String]) {
        for filename in filenames {
            try? FileManager.default.removeItem(at: url(for: filename))
            base64Cache[filename] = nil
        }
    }

    private static func downsized(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

private extension URL {
    var creationDate: Date {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
    }
}
