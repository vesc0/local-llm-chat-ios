import SwiftUI

struct OllamaModelSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var availableModels: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading models...")
                    Spacer()
                }
            } else if let errorMessage = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Could not connect to Ollama.")
                        .font(.headline)
                        .foregroundColor(.red)
                    Text("Make sure the Ollama app or service is up and running on your machine.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            } else if availableModels.isEmpty {
                Text("No models found on Ollama server.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(availableModels, id: \.self) { model in
                    Button(action: {
                        viewModel.settings.selectedModel = model
                        viewModel.settings.engine = .ollama
                        viewModel.saveSettings()
                        dismiss()
                    }) {
                        HStack {
                            Text(model)
                                .font(.headline)
                                .foregroundColor(viewModel.settings.selectedModel == model ? Theme.accent : .primary)
                                .fontWeight(viewModel.settings.selectedModel == model ? .bold : .regular)
                            Spacer()
                            if viewModel.settings.selectedModel == model && viewModel.settings.engine == .ollama {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.accent)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Ollama Models")
        .task {
            await fetchModels()
        }
        .refreshable {
            await fetchModels()
        }
    }
    
    private func fetchModels() async {
        isLoading = true
        errorMessage = nil
        do {
            let models = try await OllamaService.shared.fetchModels(host: viewModel.settings.ollamaHost)
            await MainActor.run {
                self.availableModels = models
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch models: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}
