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
        let client = LocalLLMClient(
            baseURL: URL(string: "https://mr28.ngrok.app")!,
            endpointPath: "/v1/chat/completions"
        )
        _viewModel = StateObject(wrappedValue: ChatViewModel(client: client))
    }
    
    var body: some Scene {
        WindowGroup {
            ChatView(viewModel: viewModel)
        }
    }
}
