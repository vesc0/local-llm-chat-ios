import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: ChatViewModel
    @State private var showingSettings = false
    @State private var conversationToRename: String? = nil
    @State private var newConversationTitle: String = ""
    
    var body: some View {
        List(selection: $viewModel.activeConversationId) {
            Button(action: {
                viewModel.createConversation()
            }) {
                Label("New Chat", systemImage: "square.and.pencil")
                    .foregroundColor(Theme.accent)
                    .font(.headline)
            }
            .padding(.vertical, 8)
            
            Section(header: Text("Conversations")) {
                ForEach(viewModel.conversations) { conv in
                    NavigationLink(value: conv.id) {
                        HStack {
                            Image(systemName: "bubble.left")
                            Text(conv.title)
                                .lineLimit(1)
                            Spacer()
                            if viewModel.generatingConversationIds.contains(conv.id) {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            newConversationTitle = conv.title
                            conversationToRename = conv.id
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        viewModel.deleteConversation(id: viewModel.conversations[index].id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .alert("Rename Conversation", isPresented: Binding(
            get: { conversationToRename != nil },
            set: { if !$0 { conversationToRename = nil } }
        )) {
            TextField("New Title", text: $newConversationTitle)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                if let id = conversationToRename, !newConversationTitle.isEmpty {
                    viewModel.renameConversation(id: id, newTitle: newConversationTitle)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(Theme.accent)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(viewModel)
        }
    }
}
