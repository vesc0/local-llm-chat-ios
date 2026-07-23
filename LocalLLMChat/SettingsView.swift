import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModel
    @StateObject private var modelManager = LocalModelManager.shared
    
    @State private var repoIdInput: String = ""
    @State private var debugOutput: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Model Manager")) {
                    Picker("Engine", selection: $viewModel.settings.engine) {
                        ForEach(InferenceEngine.allCases, id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                    
                    if viewModel.settings.engine == .mlx {
                        HStack {
                            Text("Active MLX Model:")
                            Spacer()
                            Text(viewModel.settings.localModelName.isEmpty ? "None" : viewModel.settings.localModelName)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.accent)
                        }
                        
                        TextField("HuggingFace Repo ID (e.g. mlx-community/Llama-3.2-1B-Instruct-4bit)", text: $repoIdInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if modelManager.isDownloading {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    ProgressView(value: modelManager.downloadProgress, total: 1.0)
                                        .tint(Theme.accent)
                                    
                                    Button(action: {
                                        modelManager.cancelDownload()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.title3)
                                    }
                                }
                                Text(modelManager.downloadStatus)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Button {
                                Task {
                                    do {
                                        try await modelManager.downloadMLXModel(repoId: repoIdInput)
                                        repoIdInput = ""
                                    } catch {
                                        print("Download error: \(error)")
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.circle.fill")
                                    Text("Download Repository")
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                            }
                            .disabled(repoIdInput.isEmpty)
                            .listRowBackground(repoIdInput.isEmpty ? Color.gray.opacity(0.3) : Theme.accent)
                        }
                        NavigationLink("Manage Downloaded Models", destination: MLXModelSelectionView())
                    } else if viewModel.settings.engine == .ollama {
                        HStack {
                            Text("Active Ollama Model:")
                            Spacer()
                            Text(viewModel.settings.selectedModel.isEmpty ? "None" : viewModel.settings.selectedModel)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.accent)
                        }
                        
                        TextField("Ollama Host URL", text: $viewModel.settings.ollamaHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                        
                        NavigationLink("Select Ollama Model", destination: OllamaModelSelectionView())
                    }
                }
                
                Section(header: Text("Storage Maintenance")) {
                    NavigationLink("Manage Uploaded Images", destination: AttachmentManagerView())
                    
                    Button(action: {
                        modelManager.clearAllStorage()
                        if viewModel.settings.engine == .mlx {
                            viewModel.settings.localModelName = ""
                        }
                        viewModel.saveSettings()
                    }) {
                        Text("Clear All Cached Models & Data")
                            .foregroundColor(.red)
                    }
                    
                    Button("Debug Storage Used") {
                        debugOutput = modelManager.debugStorage()
                    }
                    if !debugOutput.isEmpty {
                        Text(debugOutput)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $viewModel.settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button(action: {
                viewModel.saveSettings()
                dismiss()
            }) {
                Image(systemName: "checkmark")
            })
            .onAppear {
                modelManager.scanModels()
            }
            .task {
                if viewModel.settings.engine == .ollama {
                    do {
                        let models = try await OllamaService.shared.fetchModels(host: viewModel.settings.ollamaHost)
                        if !models.contains(viewModel.settings.selectedModel) {
                            await MainActor.run {
                                viewModel.settings.selectedModel = ""
                                viewModel.saveSettings()
                            }
                        }
                    } catch {
                        await MainActor.run {
                            viewModel.settings.selectedModel = ""
                            viewModel.saveSettings()
                        }
                    }
                }
            }
        }
    }
}
