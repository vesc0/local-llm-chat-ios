import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showSidebar = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationTitle("Chats")
        } detail: {
            if viewModel.activeConversationId != nil {
                ChatView()
            } else {
                Text("No chat selected")
                    .foregroundColor(Theme.textSecondary)
                    .font(.headline)
            }
        }
    }
}
