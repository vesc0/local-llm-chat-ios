import SwiftUI

struct MLXModelSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModel
    @StateObject private var modelManager = LocalModelManager.shared

    var body: some View {
        List {
            if modelManager.downloadedModels.isEmpty {
                Text("No models downloaded yet.")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
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
                                    .foregroundColor(viewModel.settings.localModelName == model.repoId ? Theme.accent : .primary)
                                    .fontWeight(viewModel.settings.localModelName == model.repoId ? .bold : .regular)
                                
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
                                    .foregroundColor(Theme.accent)
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
        .navigationTitle("Downloaded Models")
        .onAppear {
            modelManager.scanModels()
        }
    }
}
