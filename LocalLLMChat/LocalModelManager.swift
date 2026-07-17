import Foundation
import Combine
import SwiftUI
import HuggingFace

struct MLXModel: Identifiable, Equatable {
    var id: String { repoId }
    let repoId: String
    let sizeBytes: Int64
    let capabilities: [String]
    let contextLength: Int?
    let parameterCount: String?
    
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
    private var downloadTask: Task<Void, Error>?
    
    /// The HubCache directory where HubClient (used by the MLX macro) stores models.
    /// On iOS this resolves to: Library/Caches/huggingface/hub/
    private var hubCacheDir: URL {
        HubCache.default.cacheDirectory
    }
    
    init() {
        scanModels()
    }
    
    // MARK: - Scan
    
    func scanModels() {
        let cacheDir = hubCacheDir
        var foundModels: [MLXModel] = []
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDir,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        ) else {
            self.downloadedModels = []
            return
        }
        
        for url in contents {
            guard url.hasDirectoryPath else { continue }
            let folderName = url.lastPathComponent
            
            // HubCache format: models--namespace--reponame
            guard folderName.hasPrefix("models--") else { continue }
            
            // Split: ["models", "namespace", "reponame"]
            let parts = folderName.components(separatedBy: "--")
            guard parts.count >= 3 else { continue }
            
            // Handle repo names that contain "--" by joining everything after the namespace
            let namespace = parts[1]
            let name = parts[2...].joined(separator: "--")
            let repoId = "\(namespace)/\(name)"
            
            let size = directorySize(url: url)
            if size > 0 {
                let metadata = parseModelMetadata(for: url)
                let paramCount = extractParameterCount(from: repoId)
                foundModels.append(MLXModel(
                    repoId: repoId,
                    sizeBytes: size,
                    capabilities: metadata.capabilities,
                    contextLength: metadata.contextLength,
                    parameterCount: paramCount
                ))
            }
        }
        
        self.downloadedModels = foundModels.sorted { $0.repoId < $1.repoId }
    }
    
    private func parseModelMetadata(for url: URL) -> (capabilities: [String], contextLength: Int?) {
        var capabilities: [String] = ["Text"]
        var contextLength: Int? = nil
        
        let snapshotsURL = url.appendingPathComponent("snapshots")
        if let snapshots = try? fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil),
           let latestSnapshot = snapshots.first {
            let configURL = latestSnapshot.appendingPathComponent("config.json")
            if let data = try? Data(contentsOf: configURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let modelType = json["model_type"] as? String {
                    let visionTypes = ["llava", "qwen2_vl", "paligemma", "idefics2", "vision", "moondream", "pixtral", "clip", "minicpmv"]
                    if visionTypes.contains(where: { modelType.lowercased().contains($0) }) {
                        capabilities.append("Vision")
                    }
                }
                
                if let maxPos = json["max_position_embeddings"] as? Int {
                    contextLength = maxPos
                } else if let maxSeq = json["max_sequence_length"] as? Int {
                    contextLength = maxSeq
                }
            }
        }
        
        return (capabilities, contextLength)
    }
    
    private func extractParameterCount(from repoId: String) -> String? {
        let pattern = "(\\d+(?:\\.\\d+)?[bB])"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: repoId, range: NSRange(repoId.startIndex..., in: repoId)) {
            if let range = Range(match.range(at: 1), in: repoId) {
                return String(repoId[range]).uppercased()
            }
        }
        return nil
    }
    
    // MARK: - Download
    
    func downloadMLXModel(repoId: String) async throws {
        guard !repoId.isEmpty else { throw URLError(.badURL) }
        guard let repoID = Repo.ID(rawValue: repoId) else { throw URLError(.badURL) }
        
        self.isDownloading = true
        self.downloadProgress = 0.0
        self.downloadStatus = "Preparing download..."
        
        let globs = ["*.safetensors", "*.json", "*.model", "*.txt", "*.tiktoken"]
        
        // Clean up tmp directory before starting a new download so old orphaned CFNetworkDownload files don't inflate real-time progress calculation
        let tmp = fileManager.temporaryDirectory
        if let tmpContents = try? fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for url in tmpContents {
                try? fileManager.removeItem(at: url)
            }
        }
        
        // Use HubClient — same library that #huggingFaceLoadModelContainer uses.
        // This downloads into HubCache (Library/Caches/huggingface/hub/) so the MLX loader can find the files without re-downloading.
        let client = HubClient()
        
        downloadTask = Task {
            let _ = try await client.downloadSnapshot(
                of: repoID,
                matching: globs
            ) { @MainActor progress in
                let total = progress.totalUnitCount
                
                // Calculate real downloaded bytes by summing tmp downloads + cached model size
                var realCompleted: Int64 = 0
                
                let tmp = self.fileManager.temporaryDirectory
                if let enumerator = self.fileManager.enumerator(at: tmp, includingPropertiesForKeys: [.fileSizeKey]) {
                    for case let fileURL as URL in enumerator {
                        if fileURL.lastPathComponent.hasPrefix("CFNetworkDownload_") {
                            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                               let fileSize = resourceValues.fileSize {
                                realCompleted += Int64(fileSize)
                            }
                        }
                    }
                }
                
                // Add the size of the destination folder (files already completed)
                let namespace = repoID.description.split(separator: "/").first ?? ""
                let name = repoID.description.split(separator: "/").dropFirst().joined(separator: "--")
                let folderName = "models--\(namespace)--\(name)"
                let modelFolder = self.hubCacheDir.appendingPathComponent(folderName)
                realCompleted += self.directorySize(url: modelFolder)
                
                // Bypass swift-huggingface NSProgress bug for LFS files
                let reportedCompleted = progress.completedUnitCount
                let finalCompleted = max(realCompleted, reportedCompleted)
                let safeTotal = max(total, 1)
                
                var fraction = Double(finalCompleted) / Double(safeTotal)
                if fraction > 1.0 { fraction = 1.0 }
                
                withAnimation {
                    self.downloadProgress = fraction
                }
                
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useGB, .useMB]
                formatter.countStyle = .file
                let completedStr = formatter.string(fromByteCount: finalCompleted)
                let totalStr = formatter.string(fromByteCount: total)
                
                self.downloadStatus = "Downloading... \(String(format: "%.1f", fraction * 100))% (\(completedStr) / \(totalStr))"
            }
        }
        
        do {
            try await downloadTask?.value
            self.downloadProgress = 1.0
            self.downloadStatus = "Download complete!"
            self.isDownloading = false
            self.scanModels()
        } catch {
            self.isDownloading = false
            if error is CancellationError {
                self.downloadStatus = "Download cancelled."
            } else {
                self.downloadStatus = "Error: \(error.localizedDescription)"
                throw error
            }
        }
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
    }
    
    // MARK: - Delete
    
    func deleteModel(_ model: MLXModel) {
        let repoComponents = model.repoId.split(separator: "/")
        guard repoComponents.count >= 2 else { return }
        let namespace = String(repoComponents[0])
        let name = repoComponents[1...].joined(separator: "--")
        let folderName = "models--\(namespace)--\(name)"
        
        // Release any active memory/mmap locks so the OS allows deletion
        MLXService.shared.clearModel()
        
        // Delete from the HubCache directory
        let modelFolder = hubCacheDir.appendingPathComponent(folderName)
        try? fileManager.removeItem(at: modelFolder)
        
        // Also delete any .metadata for this model
        let metadataFolder = hubCacheDir.appendingPathComponent(".metadata").appendingPathComponent(folderName)
        try? fileManager.removeItem(at: metadataFolder)
        
        // Also clean up any leftover data in Documents (from old HubApi downloads)
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let legacyDir = documents.appendingPathComponent("huggingface/models/\(namespace)/\(repoComponents[1...].joined(separator: "/"))")
        try? fileManager.removeItem(at: legacyDir)
        
        // Clean up tmp directory to wipe any CFNetworkDownload orphaned files
        let tmp = fileManager.temporaryDirectory
        if let tmpContents = try? fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for url in tmpContents {
                try? fileManager.removeItem(at: url)
            }
        }
        
        scanModels()
    }
    
    func clearAllStorage() {
        // Release any active memory/mmap locks so the OS allows deletion
        MLXService.shared.clearModel()
        
        // 1. Nuke the entire HubCache directory (Library/Caches/huggingface/)
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        try? fileManager.removeItem(at: caches.appendingPathComponent("huggingface"))
        
        // 2. Legacy Documents/huggingface/ from old HubApi downloads
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        try? fileManager.removeItem(at: documents.appendingPathComponent("huggingface"))
        
        // 3. Application Support (another possible location)
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? fileManager.removeItem(at: appSupport.appendingPathComponent("huggingface"))
        
        // 4. Temp directory (where CFNetwork leaves abandoned downloads)
        let tmp = fileManager.temporaryDirectory
        if let tmpContents = try? fileManager.contentsOfDirectory(at: tmp, includingPropertiesForKeys: nil) {
            for url in tmpContents {
                try? fileManager.removeItem(at: url)
            }
        }
        
        scanModels()
    }
    
    // MARK: - Helpers
    
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
    
    func debugStorage() -> String {
        let home = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.deletingLastPathComponent()
        var result = "App Container:\n"
        
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        guard let enumerator = fileManager.enumerator(at: home, includingPropertiesForKeys: keys) else {
            return "Failed to enumerate"
        }
        
        var dirSizes: [String: Int64] = [:]
        
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory != true {
                if let size = values.fileSize {
                    // Group by top 3 path components relative to home
                    let path = fileURL.path.replacingOccurrences(of: home.path, with: "")
                    let components = path.split(separator: "/").map(String.init)
                    let groupKey = components.prefix(3).joined(separator: "/")
                    dirSizes[groupKey, default: 0] += Int64(size)
                }
            }
        }
        
        let sorted = dirSizes.sorted { $0.value > $1.value }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        
        for (dir, size) in sorted {
            
                result += "/\(dir): \(formatter.string(fromByteCount: size))\n"
            
        }
        
        return result
    }
}
