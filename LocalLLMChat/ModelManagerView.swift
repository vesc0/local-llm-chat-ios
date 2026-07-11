import SwiftUI

struct ModelManagerView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModel
    @StateObject private var modelManager = LocalModelManager.shared
    
    @State private var repoIdInput: String = ""
    @State private var debugOutput: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Engine", selection: $viewModel.settings.engine) {
                        ForEach(InferenceEngine.allCases, id: \.self) { engine in
                            Text(engine.rawValue).tag(engine)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                } header: {
                    Text("Active Inference Engine")
                } footer: {
                    if viewModel.settings.engine == .mlx {
                        Text("Active MLX Model: \(viewModel.settings.localModelName.isEmpty ? "None" : viewModel.settings.localModelName)")
                    } else {
                        Text("Active Ollama Model: \(viewModel.settings.selectedModel)")
                    }
                }
                
                if viewModel.settings.engine == .ollama {
                    Section(header: Text("Ollama Settings")) {
                        TextField("Ollama Host URL", text: $viewModel.settings.ollamaHost)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                        
                        TextField("Model Name", text: $viewModel.settings.selectedModel)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                } else if viewModel.settings.engine == .mlx {
                    Section(header: Text("Download MLX Model")) {
                        TextField("HuggingFace Repo ID (e.g. mlx-community/Llama-3.2-1B-Instruct-4bit)", text: $repoIdInput)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if modelManager.isDownloading {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 12) {
                                    ProgressView(value: modelManager.downloadProgress, total: 1.0)
                                        .tint(.blue)
                                    
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
                            .listRowBackground(repoIdInput.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        }
                    }
                    
                    Section(header: Text("Downloaded MLX Models")) {
                        if modelManager.downloadedModels.isEmpty {
                            Text("No models downloaded yet.")
                                .foregroundColor(.secondary)
                                .italic()
                        } else {
                            List {
                                ForEach(modelManager.downloadedModels) { model in
                                    Button(action: {
                                        viewModel.settings.localModelName = model.repoId
                                        viewModel.settings.engine = .mlx
                                        viewModel.saveSettings()
                                        dismiss()
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(model.repoId.components(separatedBy: "/").last ?? model.repoId)
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text(model.repoId.components(separatedBy: "/").first ?? "")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                
                                                HStack(spacing: 4) {
                                                    ForEach(model.capabilities, id: \.self) { cap in
                                                        Text(cap)
                                                            .font(.caption2)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(cap == "Vision" ? Color.purple.opacity(0.15) : Color.gray.opacity(0.15))
                                                            .foregroundColor(cap == "Vision" ? .purple : .secondary)
                                                            .cornerRadius(4)
                                                    }
                                                    
                                                    if let context = model.contextLength {
                                                        Text("\(context/1024)k")
                                                            .font(.caption2)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.green.opacity(0.15))
                                                            .foregroundColor(.green)
                                                            .cornerRadius(4)
                                                    }
                                                    
                                                    if let params = model.parameterCount {
                                                        Text(params)
                                                            .font(.caption2)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.orange.opacity(0.15))
                                                            .foregroundColor(.orange)
                                                            .cornerRadius(4)
                                                    }
                                                }
                                                .padding(.top, 2)
                                            }
                                            
                                            Spacer()
                                            
                                            Text(model.sizeString)
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                                .padding(.trailing, 4)
                                            
                                            if viewModel.settings.localModelName == model.repoId && viewModel.settings.engine == .mlx {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                                .onDelete { indexSet in
                                    for index in indexSet {
                                        let model = modelManager.downloadedModels[index]
                                        modelManager.deleteModel(model)
                                        if viewModel.settings.localModelName == model.repoId {
                                            viewModel.settings.localModelName = ""
                                        }
                                    }
                                    viewModel.saveSettings()
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $viewModel.settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section(header: Text("Storage Maintenance")) {
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
            }
            .navigationTitle("Model Manager")
            .navigationBarItems(trailing: Button("Done") {
                viewModel.saveSettings()
                dismiss()
            })
            .onAppear {
                modelManager.scanModels()
            }
        }
    }
}
