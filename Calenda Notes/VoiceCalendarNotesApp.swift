//
//  VoiceCalendarNotesApp.swift
//  Calenda Notes
//
//  Simple chat app connecting to local LLM server
//

import SwiftUI

@main
struct VoiceCalendarNotesApp: App {
    @StateObject private var viewModel: ChatViewModel
    
    init() {
        // Client reads URL dynamically from settings on each request
        let client = LocalLLMClient()
        _viewModel = StateObject(wrappedValue: ChatViewModel(client: client))
    }
    
    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}
