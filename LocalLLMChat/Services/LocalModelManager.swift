import Foundation
import SwiftUI
import HuggingFace
import os

struct MLXModel: Identifiable, Equatable, Sendable {
    var id: String { repoId }
    let repoId: String
    let sizeBytes: Int64
    let capabilities: [String]
    let contextLength: Int?
    let parameterCount: String?

    var sizeString: String { ByteCountFormatter.file.string(fromByteCount: sizeBytes) }
    var name: String { repoId.components(separatedBy: "/").last ?? repoId }
    var namespace: String { repoId.components(separatedBy: "/").first ?? "" }
}

@MainActor
final class LocalModelManager: ObservableObject {
    static let shared = LocalModelManager()

    @Published private(set) var downloadedModels: [MLXModel] = []
    @Published private(set) var downloadProgress: Double = 0
    @Published private(set) var isDownloading = false
    @Published private(set) var downloadStatus = ""

    private var downloadTask: Task<Void, any Error>?
    private var lastSample = Date.distantPast
    private var isMeasuring = false

    private nonisolated static var cacheDirectory: URL { HubCache.default.cacheDirectory }

    func scanModels() async {
        downloadedModels = await Task.detached(priority: .utility) { Self.scan() }.value
    }

    // MARK: - Download

    func download(repoId: String) async {
        let trimmed = repoId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let repo = Repo.ID(rawValue: trimmed) else {
            downloadStatus = "\"\(trimmed)\" is not a valid repository id."
            return
        }

        isDownloading = true
        downloadProgress = 0
        downloadStatus = "Preparing download…"
        await Task.detached(priority: .utility) { Self.purgeOrphanedDownloads() }.value

        let destination = Self.cacheDirectory.appending(path: Self.folderName(for: trimmed))
        let task = Task {
            _ = try await HubClient().downloadSnapshot(
                of: repo,
                matching: ["*.safetensors", "*.json", "*.model", "*.txt", "*.tiktoken"]
            ) { @MainActor progress in
                self.sampleProgress(
                    reported: progress.completedUnitCount,
                    total: progress.totalUnitCount,
                    destination: destination
                )
            }
        }
        downloadTask = task

        do {
            try await task.value
            downloadProgress = 1
            downloadStatus = "Download complete."
        } catch is CancellationError {
            downloadStatus = "Download cancelled."
        } catch {
            Logger.app.error("Download failed: \(error)")
            downloadStatus = "Error: \(error.localizedDescription)"
        }
        isDownloading = false
        downloadTask = nil
        await scanModels()
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    /// Drops the outcome of a finished download so it cannot resurface later
    /// as if it had just happened.
    func clearStatus() {
        guard !isDownloading else { return }
        downloadStatus = ""
        downloadProgress = 0
    }

    /// The reported count is wrong for LFS files, so real bytes on disk are measured
    /// instead — throttled and off the main actor, since it walks the download folder.
    private func sampleProgress(reported: Int64, total: Int64, destination: URL) {
        guard !isMeasuring, Date().timeIntervalSince(lastSample) > 0.5 else { return }
        isMeasuring = true
        lastSample = Date()

        Task.detached(priority: .utility) { [weak self] in
            let measured = Self.bytesOnDisk(destination: destination)
            await self?.applyProgress(completed: max(measured, reported), total: total)
        }
    }

    private func applyProgress(completed: Int64, total: Int64) {
        isMeasuring = false
        guard isDownloading else { return }
        let fraction = min(Double(completed) / Double(max(total, 1)), 1)
        withAnimation { downloadProgress = fraction }
        downloadStatus = """
            Downloading… \(Int(fraction * 100))% \
            (\(ByteCountFormatter.file.string(fromByteCount: completed)) / \
            \(ByteCountFormatter.file.string(fromByteCount: total)))
            """
    }

    // MARK: - Delete

    func delete(_ model: MLXModel) async {
        await MLXRuntime.shared.unload()  // releases the mmap so the files can be removed
        let folder = Self.folderName(for: model.repoId)
        await Task.detached(priority: .utility) {
            let manager = FileManager.default
            try? manager.removeItem(at: Self.cacheDirectory.appending(path: folder))
            try? manager.removeItem(at: Self.cacheDirectory.appending(path: ".metadata").appending(path: folder))
            Self.purgeOrphanedDownloads()
        }.value
        await scanModels()
    }

    func clearAllStorage() async {
        await MLXRuntime.shared.unload()
        await Task.detached(priority: .utility) {
            let manager = FileManager.default
            for directory in [URL.cachesDirectory, .documentsDirectory, .applicationSupportDirectory] {
                try? manager.removeItem(at: directory.appending(path: "huggingface"))
            }
            Self.purgeOrphanedDownloads()
        }.value
        await scanModels()
    }

    // MARK: - Filesystem

    private nonisolated static func scan() -> [MLXModel] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        )) ?? []

        return contents.compactMap { url -> MLXModel? in
            guard url.hasDirectoryPath else { return nil }
            // HubCache lays models out as models--namespace--repo-name.
            let parts = url.lastPathComponent.components(separatedBy: "--")
            guard parts.first == "models", parts.count >= 3 else { return nil }

            let repoId = "\(parts[1])/\(parts[2...].joined(separator: "--"))"
            let size = directorySize(url)
            guard size > 0 else { return nil }

            let metadata = self.metadata(in: url)
            return MLXModel(
                repoId: repoId,
                sizeBytes: size,
                capabilities: metadata.capabilities,
                contextLength: metadata.contextLength,
                parameterCount: parameterCount(in: repoId)
            )
        }
        .sorted { $0.repoId < $1.repoId }
    }

    private nonisolated static func metadata(in modelFolder: URL) -> (capabilities: [String], contextLength: Int?) {
        let snapshots = (try? FileManager.default.contentsOfDirectory(
            at: modelFolder.appending(path: "snapshots"), includingPropertiesForKeys: nil
        )) ?? []
        guard let snapshot = snapshots.first,
              let data = try? Data(contentsOf: snapshot.appending(path: "config.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return (["Text"], nil) }

        var capabilities = ["Text"]
        let visionTypes = ["llava", "qwen2_vl", "paligemma", "idefics2", "vision", "moondream", "pixtral", "clip", "minicpmv"]
        if let type = (json["model_type"] as? String)?.lowercased(),
           visionTypes.contains(where: type.contains) {
            capabilities.append("Vision")
        }
        let context = json["max_position_embeddings"] as? Int ?? json["max_sequence_length"] as? Int
        return (capabilities, context)
    }

    private nonisolated static let parameterRegex = try? NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)[bB]\b"#)

    private nonisolated static func parameterCount(in repoId: String) -> String? {
        guard let match = parameterRegex?.firstMatch(
            in: repoId, range: NSRange(repoId.startIndex..., in: repoId)
        ), let range = Range(match.range(at: 1), in: repoId) else { return nil }
        return repoId[range] + "B"
    }

    private nonisolated static func folderName(for repoId: String) -> String {
        let parts = repoId.components(separatedBy: "/")
        return "models--\(parts.first ?? "")--\(parts.dropFirst().joined(separator: "--"))"
    }

    private nonisolated static func bytesOnDisk(destination: URL) -> Int64 {
        inFlightDownloads().reduce(directorySize(destination)) { $0 + $1.fileSize }
    }

    /// Only CFNetwork's abandoned partial downloads — other subsystems use tmp too.
    private nonisolated static func inFlightDownloads() -> [URL] {
        let tmp = FileManager.default.temporaryDirectory
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: tmp, includingPropertiesForKeys: [.fileSizeKey]
        )) ?? []
        return contents.filter { $0.lastPathComponent.hasPrefix("CFNetworkDownload_") }
    }

    private nonisolated static func purgeOrphanedDownloads() {
        for url in inFlightDownloads() { try? FileManager.default.removeItem(at: url) }
    }

    private nonisolated static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return enumerator.reduce(into: Int64(0)) { total, item in
            if let url = item as? URL { total += url.fileSize }
        }
    }
}

extension ByteCountFormatter {
    static let file: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter
    }()
}

private extension URL {
    var fileSize: Int64 {
        Int64((try? resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
}
