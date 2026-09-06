import SwiftUI

struct MLXModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel
    @ObservedObject private var modelManager = LocalModelManager.shared

    var body: some View {
        List {
            if modelManager.downloadedModels.isEmpty {
                ContentUnavailableView(
                    "No Models",
                    systemImage: "square.and.arrow.down",
                    description: Text("Download one from Settings using its Hugging Face repo id.")
                )
            } else {
                ForEach(modelManager.downloadedModels) { model in
                    Button { select(model) } label: { row(model) }
                }
                .onDelete { offsets in
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
            }
        }
        .navigationTitle("Downloaded Models")
        .task { await modelManager.scanModels() }
    }

    private func select(_ model: MLXModel) {
        viewModel.settings.localModelName = model.repoId
        viewModel.settings.engine = .mlx
        dismiss()
    }

    private func row(_ model: MLXModel) -> some View {
        let isSelected = viewModel.settings.localModelName == model.repoId

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.name)
                    .font(.headline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundStyle(isSelected ? Theme.accent : .primary)
                Text(model.namespace).font(.caption).foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ForEach(model.capabilities, id: \.self) { capability in
                        Badge(capability, color: capability == "Vision" ? .purple : .secondary)
                    }
                    if let context = model.contextLength {
                        Badge("\(context / 1024)k", color: .green)
                    }
                    if let parameters = model.parameterCount {
                        Badge(parameters, color: .orange)
                    }
                }
                .padding(.top, 2)
            }

            Spacer()
            Badge(model.sizeString, color: .blue)

            if isSelected && viewModel.settings.engine == .mlx {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
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
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15), in: .rect(cornerRadius: 4))
            .foregroundStyle(color)
    }
}
