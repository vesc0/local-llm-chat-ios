import Foundation
import Combine
import SwiftUI
import HuggingFace
import Hub

struct MLXModel: Identifiable, Equatable {
    var id: String { repoId }
    let repoId: String
    let sizeBytes: Int64
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }
}

@MainActor
class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()
    
    @Published var downloadedModels: [MLXModel] = []
    
    @Published var downloadProgress: Double = 0.0
    @Published var isDownloading: Bool = false
    @Published var downloadStatus: String = ""
    
    private let fileManager = FileManager.default
    
    init() {
        scanModels()
    }
    
    func scanModels() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let hfModelsDir = documents.appendingPathComponent("huggingface/models")
        
        var foundModels: [MLXModel] = []
        
        guard let namespaces = try? fileManager.contentsOfDirectory(at: hfModelsDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            self.downloadedModels = []
            return
        }
        
        for namespaceUrl in namespaces {
            guard namespaceUrl.hasDirectoryPath else { continue }
            let namespace = namespaceUrl.lastPathComponent
            
            guard let repos = try? fileManager.contentsOfDirectory(at: namespaceUrl, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
                continue
            }
            
            for repoUrl in repos {
                guard repoUrl.hasDirectoryPath else { continue }
                let repoName = repoUrl.lastPathComponent
                let repoId = "\(namespace)/\(repoName)"
                
                let size = directorySize(url: repoUrl)
                foundModels.append(MLXModel(repoId: repoId, sizeBytes: size))
            }
        }
        
        self.downloadedModels = foundModels.sorted { $0.repoId < $1.repoId }
    }
    
    private func directorySize(url: URL) -> Int64 {
        var size: Int64 = 0
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            size += Int64(fileSize)
        }
        return size
    }
    
    func downloadMLXModel(repoId: String) async throws {
        guard !repoId.isEmpty else { throw URLError(.badURL) }
        
        self.isDownloading = true
        self.downloadProgress = 0.0
        self.downloadStatus = "Preparing download..."
        
        let repo = HubApi.Repo(id: repoId, type: .models)
        
        // Use swift-transformers HubApi to snapshot the repo.
        // Match safetensors, json config, tokenizers, etc.
        let globs = ["*.safetensors", "*.json", "*.model", "*.txt", "*.tiktoken"]
        
        do {
            try await HubApi.shared.snapshot(from: repo, matching: globs) { progress in
                Task { @MainActor in
                    self.downloadProgress = progress.fractionCompleted
                    self.downloadStatus = "Downloading... \(String(format: "%.1f", progress.fractionCompleted * 100))%"
                }
            }
            
            self.downloadProgress = 1.0
            self.downloadStatus = "Download complete!"
            self.isDownloading = false
            self.scanModels()
        } catch {
            self.isDownloading = false
            self.downloadStatus = "Error: \(error.localizedDescription)"
            throw error
        }
    }
    
    func deleteModel(_ model: MLXModel) {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let repoComponents = model.repoId.split(separator: "/")
        guard repoComponents.count == 2 else { return }
        let namespace = String(repoComponents[0])
        let name = String(repoComponents[1])
        
        let dir = documents.appendingPathComponent("huggingface/models/\(namespace)/\(name)")
        try? fileManager.removeItem(at: dir)
        
        // Also remove namespace dir if empty
        let namespaceDir = documents.appendingPathComponent("huggingface/models/\(namespace)")
        if let contents = try? fileManager.contentsOfDirectory(atPath: namespaceDir.path), contents.isEmpty {
            try? fileManager.removeItem(at: namespaceDir)
        }
        
        scanModels()
    }
}
