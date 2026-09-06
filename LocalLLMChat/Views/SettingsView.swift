import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel
    @ObservedObject private var modelManager = LocalModelManager.shared

    @State private var repoId = ""
    @State private var confirmingClear = false

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

                    switch viewModel.settings.engine {
                    case .mlx: mlxSection
                    case .ollama: ollamaSection
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
            .task { await modelManager.scanModels() }
        }
    }

    @ViewBuilder
    private var mlxSection: some View {
        LabeledContent("Active Model") {
            Text(viewModel.settings.localModelName.isEmpty ? "None" : viewModel.settings.localModelName)
                .fontWeight(.bold)
                .foregroundStyle(Theme.accent)
        }

        TextField("Hugging Face repo id", text: $repoId)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

        if modelManager.isDownloading {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ProgressView(value: modelManager.downloadProgress).tint(Theme.accent)
                    Button("Cancel download", systemImage: "xmark.circle.fill") {
                        modelManager.cancelDownload()
                    }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                    .font(.title3)
                }
                Text(modelManager.downloadStatus).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } else {
            Button {
                Task {
                    await modelManager.download(repoId: repoId)
                    repoId = ""
                }
            } label: {
                Label("Download Repository", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .disabled(repoId.trimmingCharacters(in: .whitespaces).isEmpty)

            if !modelManager.downloadStatus.isEmpty {
                Text(modelManager.downloadStatus).font(.caption).foregroundStyle(.secondary)
            }
        }

        NavigationLink("Manage Downloaded Models") { MLXModelSelectionView() }
    }

    @ViewBuilder
    private var ollamaSection: some View {
        LabeledContent("Active Model") {
            Text(viewModel.settings.selectedModel.isEmpty ? "None" : viewModel.settings.selectedModel)
                .fontWeight(.bold)
                .foregroundStyle(Theme.accent)
        }

        TextField("http://192.168.1.10:11434", text: $viewModel.settings.ollamaHost)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)

        NavigationLink("Select Ollama Model") { OllamaModelSelectionView() }
    }
}
