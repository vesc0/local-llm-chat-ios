import SwiftUI

struct OllamaModelSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: ChatViewModel

    @State private var models: [String] = []
    @State private var errorMessage: String?
    @State private var isConnecting = false
    @State private var hasConnected = false

    private var host: String {
        viewModel.settings.ollamaHost.trimmingCharacters(in: .whitespaces)
    }

    private var canConnect: Bool { !host.isEmpty && !isConnecting }

    var body: some View {
        Form {
            Section {
                // The hint is drawn manually: iOS tints a URL-shaped placeholder
                // with the accent color, which reads as an already-entered value.
                TextField("", text: $viewModel.settings.ollamaHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .accessibilityLabel("Ollama server address")
                    .overlay(alignment: .leading) {
                        if viewModel.settings.ollamaHost.isEmpty {
                            Text(verbatim: "http://192.168.1.10:11434")
                                .foregroundStyle(.secondary)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    Task { await connect() }
                } label: {
                    HStack {
                        Label("Connect", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if isConnecting { ProgressView() }
                    }
                    .foregroundStyle(canConnect ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                }
                .disabled(!canConnect)
            } header: {
                Text("Server")
            } footer: {
                Text("Use your machine's IP address. A hostname over plain HTTP is blocked by iOS.")
            }

            if let errorMessage {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Could not reach Ollama.").font(.headline).foregroundStyle(.red)
                        Text("Check that Ollama is running and that the address above is correct.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(errorMessage).font(.caption).foregroundStyle(.red.opacity(0.8))
                    }
                    .padding(.vertical, 4)
                }
            } else if !models.isEmpty {
                Section {
                    Text("Tap a model to select it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))

                    ForEach(models, id: \.self) { model in
                        Button { select(model) } label: { row(model) }
                    }
                } header: {
                    Text("Models")
                }
            } else if hasConnected && !isConnecting {
                Section {
                    Text("No models found on the server.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ollama")
        .task {
            // Reconnect automatically when a server is already configured.
            if !host.isEmpty && !hasConnected { await connect() }
        }
    }

    private func row(_ model: String) -> some View {
        let isSelected = viewModel.settings.selectedModel == model
            && viewModel.settings.engine == .ollama

        return HStack {
            Text(model)
                .font(.headline)
                .fontWeight(isSelected ? .bold : .regular)
                .foregroundStyle(isSelected ? Theme.accent : .primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func select(_ model: String) {
        viewModel.settings.selectedModel = model
        viewModel.settings.engine = .ollama
        dismiss()
    }

    private func connect() async {
        isConnecting = true
        errorMessage = nil
        do {
            models = try await OllamaService.fetchModels(host: host)
        } catch {
            // The saved selection is left alone: a transient failure must not discard it.
            models = []
            errorMessage = error.localizedDescription
        }
        hasConnected = true
        isConnecting = false
    }
}
