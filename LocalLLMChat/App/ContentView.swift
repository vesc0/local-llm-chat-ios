import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ChatViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView().navigationTitle("Chats")
        } detail: {
            if viewModel.activeConversationId != nil {
                ChatView()
            } else {
                ContentUnavailableView("No Chat Selected", systemImage: "bubble.left.and.bubble.right")
            }
        }
        .preferredColorScheme(viewModel.settings.themeMode.colorScheme)
    }
}

extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .auto: nil
        }
    }
}
