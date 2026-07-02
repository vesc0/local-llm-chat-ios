import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: ChatViewModel
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ollama Settings")) {
                    TextField("Ollama Host URL", text: $viewModel.settings.ollamaHost)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)
                    
                    TextField("Model Name", text: $viewModel.settings.selectedModel)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $viewModel.settings.themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section(footer: Text("Ensure your Ollama server is running and accessible on the local network.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                viewModel.saveSettings()
                dismiss()
            })
        }
    }
}
