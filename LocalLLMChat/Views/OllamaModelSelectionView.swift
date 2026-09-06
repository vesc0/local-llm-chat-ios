import SwiftUI

struct OllamaModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel

    @State private var models: [String] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading models…")
                    Spacer()
                }
            } else if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Could not reach Ollama.").font(.headline).foregroundStyle(.red)
                    Text("Check that Ollama is running and that the host in Settings is correct.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(errorMessage).font(.caption).foregroundStyle(.red.opacity(0.8))
                }
                .padding(.vertical, 8)
            } else if models.isEmpty {
                Text("No models found on the server.").foregroundStyle(.secondary)
            } else {
                ForEach(models, id: \.self) { model in
                    Button { select(model) } label: {
                        HStack {
                            Text(model)
                                .font(.headline)
                                .fontWeight(viewModel.settings.selectedModel == model ? .bold : .regular)
                                .foregroundStyle(viewModel.settings.selectedModel == model ? Theme.accent : .primary)
                            Spacer()
                            if viewModel.settings.selectedModel == model,
                               viewModel.settings.engine == .ollama {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Ollama Models")
        .task { await load() }
        .refreshable { await load() }
    }

    private func select(_ model: String) {
        viewModel.settings.selectedModel = model
        viewModel.settings.engine = .ollama
        dismiss()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            models = try await OllamaService.fetchModels(host: viewModel.settings.ollamaHost)
        } catch {
            // The selection is deliberately left alone: a transient failure
            // must not discard the user's configured model.
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
