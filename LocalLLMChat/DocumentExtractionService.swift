import Foundation
import PDFKit

class DocumentExtractionService {
    static let shared = DocumentExtractionService()
    
    func extractText(from url: URL) -> String? {
        // Handle PDF
        if url.pathExtension.lowercased() == "pdf" {
            return extractPDFText(from: url)
        }
        
        // Handle text files (txt, md, csv, etc.)
        do {
            // Start accessing security-scoped resource just in case it's from UIDocumentPicker
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let text = try String(contentsOf: url, encoding: .utf8)
            return text
        } catch {
            print("Failed to extract text from file: \(error)")
            return nil
        }
    }
    
    private func extractPDFText(from url: URL) -> String? {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        
        var fullText = ""
        for i in 0..<pdfDocument.pageCount {
            if let page = pdfDocument.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        
        return fullText.isEmpty ? nil : fullText
    }
}
