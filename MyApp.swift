import SwiftUI

@main
struct MyApp: App {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(viewModel.settings.themeMode == .dark ? .dark : (viewModel.settings.themeMode == .light ? .light : nil))
        }
    }
}
