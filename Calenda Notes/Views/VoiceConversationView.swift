//
//  VoiceConversationView.swift
//  Calenda Notes
//

import SwiftUI

struct VoiceConversationView: View {
    @ObservedObject var viewModel: ChatViewModel
    @StateObject private var voiceService = VoiceService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var isActive = false
    @State private var isAutoMode = true // Automatic continuous conversation
    @State private var isProcessing = false
    @State private var currentTranscript = ""
    @State private var lastResponse = ""
    @State private var orbScale: CGFloat = 1.0
    @State private var orbOpacity: Double = 0.6
    @State private var innerOrbScale: CGFloat = 1.0
    @State private var wasInterrupted = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Animated Orb
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.3),
                                        Color.purple.opacity(0.3),
                                        Color.cyan.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 200 + CGFloat(i * 40), height: 200 + CGFloat(i * 40))
                            .scaleEffect(orbScale + CGFloat(i) * 0.1)
                            .opacity(orbOpacity - Double(i) * 0.2)
                    }
                    
                    // Main orb
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.blue.opacity(0.6),
                                    Color.purple.opacity(0.8),
                                    Color.black
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(innerOrbScale)
                        .shadow(color: .blue.opacity(0.5), radius: 30)
                        .shadow(color: .purple.opacity(0.3), radius: 50)
                    
                    // Inner highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.0)
                                ],
                                center: UnitPoint(x: 0.35, y: 0.35),
                                startRadius: 0,
                                endRadius: 50
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(innerOrbScale)
                }
                .onAppear {
                    startIdleAnimation()
                }
                
                Spacer()
                
                // Transcript display
                VStack(spacing: 16) {
                    if !currentTranscript.isEmpty {
                        Text(currentTranscript)
                            .font(.title3)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .transition(.opacity)
                    }
                    
                    if !lastResponse.isEmpty && !voiceService.isSpeaking {
                        Text(lastResponse)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 32)
                    }
                }
                .frame(height: 120)
                
                // Control buttons
                HStack(spacing: 60) {
                    // Stop button
                    Button(action: stopConversation) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.2))
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "stop.fill")
                                    .font(.title2)
                                    .foregroundColor(.red)
                            }
                            Text("Stop")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Main mic button - can interrupt AI speech
                    Button(action: {
                        if voiceService.isSpeaking {
                            // Interrupt the AI
                            voiceService.stopSpeaking()
                            startListening()
                        } else {
                            toggleListening()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(
                                    voiceService.isListening ?
                                    AnyShapeStyle(Color.red) :
                                    AnyShapeStyle(LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                )
                                .frame(width: 80, height: 80)
                                .shadow(color: voiceService.isListening ? Color.red.opacity(0.5) : Color.blue.opacity(0.5), radius: 10)
                            
                            Image(systemName: voiceService.isListening ? "waveform" : (voiceService.isSpeaking ? "hand.raised.fill" : "mic.fill"))
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Return to chat button
                    Button(action: { dismiss() }) {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "keyboard")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            Text("Chat")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            Task {
                let granted = await voiceService.requestPermissions()
                if granted {
                    startListening()
                }
            }
        }
        .onDisappear {
            voiceService.stopAll()
        }
        .onChange(of: voiceService.audioLevel) { _, level in
            updateOrbAnimation(for: level)
        }
        .onChange(of: voiceService.isSpeaking) { _, speaking in
            if speaking {
                startSpeakingAnimation()
            } else {
                startIdleAnimation()
            }
        }
        .onChange(of: isProcessing) { _, processing in
            if processing {
                startProcessingAnimation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceInterruptDetected)) { _ in
            // User interrupted by speaking - start listening
            wasInterrupted = true
            currentTranscript = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                startListening()
            }
        }
    }
    
    private var statusText: String {
        if isProcessing {
            return "Thinking..."
        } else if voiceService.isSpeaking {
            return "Speaking..."
        } else if voiceService.isListening {
            return "Listening..."
        } else if isAutoMode {
            return "Ready"
        } else {
            return "Tap to speak"
        }
    }
    
    private func startIdleAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            orbScale = 1.05
            orbOpacity = 0.7
        }
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            innerOrbScale = 1.02
        }
    }
    
    private func startSpeakingAnimation() {
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            orbScale = 1.15
            orbOpacity = 0.9
            innerOrbScale = 1.1
        }
    }
    
    private func startProcessingAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            orbScale = 1.08
            orbOpacity = 0.5
            innerOrbScale = 0.95
        }
    }
    
    private func updateOrbAnimation(for level: Float) {
        let scale = 1.0 + CGFloat(level) * 0.3
        withAnimation(.easeOut(duration: 0.1)) {
            innerOrbScale = scale
            orbOpacity = 0.6 + Double(level) * 0.4
        }
    }
    
    private func startListening() {
        currentTranscript = ""
        lastResponse = ""
        voiceService.startListening { transcript in
            currentTranscript = transcript
            sendMessage(transcript)
        }
    }
    
    private func toggleListening() {
        if voiceService.isListening {
            voiceService.stopListening()
        } else {
            startListening()
        }
    }
    
    private func stopConversation() {
        voiceService.stopAll()
        currentTranscript = ""
    }
    
    private func sendMessage(_ text: String) {
        guard !text.isEmpty else {
            // Empty transcript - restart listening immediately in auto mode
            if isAutoMode {
                startListening()
            }
            return
        }
        
        isProcessing = true
        
        // Add user message to chat
        let userMessage = ChatMessage(text: text, isUser: true)
        viewModel.messages.append(userMessage)
        
        Task {
            do {
                // Build messages with system prompt
                var historyForLLM = viewModel.messages.map { msg in
                    ChatMessage(text: msg.text, isUser: msg.isUser)
                }
                
                // Use streaming for faster first response
                var fullResponse = ""
                fullResponse = try await viewModel.client.streamMessage(history: historyForLLM, userInput: text) { chunk in
                    // Update last response as it streams
                    Task { @MainActor in
                        lastResponse = (lastResponse.isEmpty ? "" : lastResponse) + chunk
                    }
                }
                
                isProcessing = false
                
                // Process any actions
                let processedReply = await processActions(in: fullResponse)
                
                // Add response to chat
                let reply = ChatMessage(text: processedReply, isUser: false)
                viewModel.messages.append(reply)
                
                lastResponse = processedReply
                
                // Speak the response
                voiceService.speak(cleanTextForSpeech(processedReply)) {
                    // Auto-start listening immediately after speaking (no delay!)
                    if isAutoMode {
                        startListening()
                    }
                }
            } catch {
                isProcessing = false
                lastResponse = "Sorry, couldn't process that."
                voiceService.speak(lastResponse) {
                    if isAutoMode {
                        startListening()
                    }
                }
            }
        }
    }
    
    private func cleanTextForSpeech(_ text: String) -> String {
        // Remove markdown and special characters for cleaner speech
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "#", with: "")
        cleaned = cleaned.replacingOccurrences(of: "`", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[", with: "")
        cleaned = cleaned.replacingOccurrences(of: "]", with: "")
        // Remove URLs
        cleaned = cleaned.replacingOccurrences(of: #"https?://\S+"#, with: "", options: .regularExpression)
        return cleaned
    }
    
    private func processActions(in text: String) async -> String {
        var result = text
        
        let pattern = #"\[ACTION:([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        for match in matches.reversed() {
            guard let range = Range(match.range, in: text),
                  let actionRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            
            let actionString = String(text[actionRange])
            let actionResult = await viewModel.actionExecutor.parseAndExecute(action: actionString, parameters: [:])
            result = result.replacingCharacters(in: range, with: actionResult)
        }
        
        return result
    }
}

#Preview {
    VoiceConversationView(viewModel: ChatViewModel(client: LocalLLMClient()))
}

