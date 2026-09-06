import Foundation
import PDFKit
import os

enum DocumentExtractor {
    /// Reads a picked document's text. Call off the main actor; PDFs can be large.
    static func text(from url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url) else { return nil }
            let text = (0..<document.pageCount)
                .compactMap { document.page(at: $0)?.string }
                .joined(separator: "\n")
            return text.isEmpty ? nil : text
        }

        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            Logger.app.error("Failed to read \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
