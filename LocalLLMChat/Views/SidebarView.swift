import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @State private var showingSettings = false
    @State private var renamingId: String?
    @State private var draftTitle = ""

    var body: some View {
        List(selection: $viewModel.activeConversationId) {
            Button {
                viewModel.createConversation()
            } label: {
                Label("New Chat", systemImage: "square.and.pencil")
                    .foregroundStyle(Theme.accent)
                    .font(.headline)
            }
            .padding(.vertical, 8)

            Section("Conversations") {
                ForEach(viewModel.conversations) { conversation in
                    NavigationLink(value: conversation.id) {
                        HStack {
                            Image(systemName: "bubble.left")
                            Text(conversation.title).lineLimit(1)
                            Spacer()
                            if viewModel.generatingConversationIds.contains(conversation.id) {
                                ProgressView().controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            draftTitle = conversation.title
                            renamingId = conversation.id
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
                .onDelete { offsets in
                    for id in offsets.map({ viewModel.conversations[$0].id }) {
                        viewModel.deleteConversation(id: id)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .alert("Rename Conversation", isPresented: .init(
            get: { renamingId != nil },
            set: { if !$0 { renamingId = nil } }
        )) {
            TextField("New Title", text: $draftTitle)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                if let id = renamingId { viewModel.renameConversation(id: id, to: draftTitle) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") { showingSettings = true }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView().environmentObject(viewModel)
        }
    }
}
