import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel
    @ObservedObject private var modelManager = LocalModelManager.shared

    @State private var confirmingClear = false
    @State private var reachableModels: [String]?
    @State private var isCheckingOllama = false

    /// A model counts as active only while it can actually be used: downloaded
    /// for MLX, served by a reachable host for Ollama. The stored selection is
    /// never discarded, so it returns as soon as the model is available again.
    private var activeModelIsAvailable: Bool {
        switch viewModel.settings.engine {
        case .mlx:
            modelManager.downloadedModels.contains { $0.repoId == viewModel.settings.localModelName }
        case .ollama:
            reachableModels?.contains(viewModel.settings.selectedModel) ?? false
        }
    }

    private var availabilityKey: String {
        [
            viewModel.settings.engine.rawValue,
            viewModel.settings.ollamaHost,
            viewModel.settings.selectedModel,
            viewModel.settings.localModelName,
        ].joined(separator: "|")
    }

    private func refreshAvailability() async {
        switch viewModel.settings.engine {
        case .mlx:
            await modelManager.scanModels()
        case .ollama:
            let host = viewModel.settings.ollamaHost.trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty else {
                reachableModels = []
                return
            }
            isCheckingOllama = true
            reachableModels = try? await OllamaService.fetchModels(host: host)
            isCheckingOllama = false
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Model Manager") {
                    Picker("Engine", selection: $viewModel.settings.engine) {
                        ForEach(InferenceEngine.allCases, id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)

                    LabeledContent("Active Model") {
                        if isCheckingOllama {
                            ProgressView()
                        } else if activeModelIsAvailable, let name = viewModel.settings.activeModelName {
                            Text(name).fontWeight(.bold).foregroundStyle(Theme.accent)
                        } else {
                            Text("None").fontWeight(.bold).foregroundStyle(.red)
                        }
                    }

                    switch viewModel.settings.engine {
                    case .mlx:
                        NavigationLink("Manage Models") { MLXModelSelectionView() }
                    case .ollama:
                        NavigationLink("Select Ollama Model") { OllamaModelSelectionView() }
                    }
                }

                Section("Storage") {
                    NavigationLink("Manage Uploaded Images") { AttachmentManagerView() }
                    Button("Clear All Cached Models & Data", role: .destructive) {
                        confirmingClear = true
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $viewModel.settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                // .confirmationAction is rendered as a standard "Done" button and
                // ignores custom label content, so place it explicitly.
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Done")
                }
            }
            .task(id: availabilityKey) { await refreshAvailability() }
            .confirmationDialog(
                "Delete all downloaded models and cached data?",
                isPresented: $confirmingClear,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    Task {
                        await modelManager.clearAllStorage()
                        viewModel.settings.localModelName = ""
                    }
                }
            }
        }
    }
}
