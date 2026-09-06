//
//  LocalLLMChatApp.swift
//  LocalLLMChat
//
//  Created by Vesco on 7/5/26.
//

import SwiftUI

@main
struct LocalLLMChatApp: App {
    @StateObject private var viewModel = ChatViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
