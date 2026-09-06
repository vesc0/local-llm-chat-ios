import SwiftUI

struct MLXModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel
    @ObservedObject private var modelManager = LocalModelManager.shared

    @State private var repoId = ""

    private var canDownload: Bool {
        !repoId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("Hugging Face repo id", text: $repoId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if modelManager.isDownloading {
                    HStack(spacing: 12) {
                        ProgressView(value: modelManager.downloadProgress).tint(Theme.accent)
                        Button("Cancel download", systemImage: "xmark.circle.fill") {
                            modelManager.cancelDownload()
                        }
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.red)
                        .font(.title3)
                    }
                } else {
                    Button {
                        Task {
                            await modelManager.download(repoId: repoId)
                            repoId = ""
                        }
                    } label: {
                        Label("Download", systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(canDownload ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                    }
                    .disabled(!canDownload)
                }

                if !modelManager.downloadStatus.isEmpty {
                    Text(modelManager.downloadStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Download")
            } 

            Section {
                if modelManager.downloadedModels.isEmpty {
                    Text("No models downloaded yet.").foregroundStyle(.secondary)
                } else {
                    Text("Tap a model to select it. Swipe left to delete.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))

                    ForEach(modelManager.downloadedModels) { model in
                        Button { select(model) } label: { row(model) }
                    }
                    .onDelete(perform: delete)
                }
            } header: {
                Text("Downloaded")
            }
        }
        .navigationTitle("Models")
        .task {
            modelManager.clearStatus()
            await modelManager.scanModels()
        }
    }

    private func select(_ model: MLXModel) {
        viewModel.settings.localModelName = model.repoId
        viewModel.settings.engine = .mlx
        dismiss()
    }

    private func delete(_ offsets: IndexSet) {
        let models = offsets.map { modelManager.downloadedModels[$0] }
        Task {
            for model in models {
                await modelManager.delete(model)
                if viewModel.settings.localModelName == model.repoId {
                    viewModel.settings.localModelName = ""
                }
            }
        }
    }

    private func row(_ model: MLXModel) -> some View {
        let isSelected = viewModel.settings.localModelName == model.repoId
            && viewModel.settings.engine == .mlx

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? Theme.accent : .primary)
                Text(model.namespace).font(.caption).foregroundStyle(.secondary)

                WrappingBadges {
                    ForEach(model.capabilities, id: \.self) { capability in
                        Badge(capability, color: capability == "Vision" ? .purple : .secondary)
                    }
                    if let context = model.contextLength {
                        Badge("\(context / 1024)k context", color: .green)
                    }
                    if let parameters = model.parameterCount {
                        Badge("\(parameters) params", color: .orange)
                    }
                    Badge("\(model.sizeString) on disk", color: .blue)
                }
                .padding(.top, 2)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Badges flow onto a second line rather than being clipped on narrow screens.
private struct WrappingBadges<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { content }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) { content }
            }
        }
    }
}

struct Badge: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: .rect(cornerRadius: 4))
            .foregroundStyle(color)
    }
}
