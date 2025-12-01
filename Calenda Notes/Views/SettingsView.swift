//
//  SettingsView.swift
//  Calenda Notes
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showClearMemoryAlert = false
    @State private var showResetAlert = false
    private let synthesizer = AVSpeechSynthesizer()
    
    private var currentVoiceName: String {
        if !settings.voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            return voice.name
        }
        return "Default"
    }
    
    private var speedLabel: String {
        switch settings.voiceSpeed {
        case 0..<0.4: return "Slow"
        case 0.4..<0.55: return "Normal"
        case 0.55...: return "Fast"
        default: return "Normal"
        }
    }
    
    private var pitchLabel: String {
        switch settings.voicePitch {
        case 0..<0.9: return "Low"
        case 0.9..<1.1: return "Normal"
        case 1.1...: return "High"
        default: return "Normal"
        }
    }
    
    private func testVoice() {
        let utterance = AVSpeechUtterance(string: "Hey! I'm Nova, your AI assistant. How can I help you today?")
        utterance.rate = Float(settings.voiceSpeed)
        utterance.pitchMultiplier = Float(settings.voicePitch)
        
        if !settings.voiceIdentifier.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.voiceIdentifier) {
            utterance.voice = voice
        }
        
        // Configure audio
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - LLM Settings
                Section {
                    // Temperature
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Temperature")
                                .font(.headline)
                            Spacer()
                            Text(String(format: "%.2f", settings.temperature))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        Slider(value: $settings.temperature, in: 0...2, step: 0.1)
                            .tint(.blue)
                        
                        // Preset buttons
                        HStack(spacing: 8) {
                            ForEach(AppSettings.TemperaturePreset.allCases, id: \.self) { preset in
                                Button(action: { settings.temperature = preset.value }) {
                                    Text(preset.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            AppSettings.TemperaturePreset.closest(to: settings.temperature) == preset
                                            ? Color.blue
                                            : Color.gray.opacity(0.2)
                                        )
                                        .foregroundColor(
                                            AppSettings.TemperaturePreset.closest(to: settings.temperature) == preset
                                            ? .white
                                            : .primary
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        
                        Text(AppSettings.TemperaturePreset.closest(to: settings.temperature).description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    // Max Tokens
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Max Tokens")
                            Text("Response length limit")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $settings.maxTokens) {
                            Text("512").tag(512)
                            Text("1024").tag(1024)
                            Text("2048").tag(2048)
                            Text("4096").tag(4096)
                        }
                        .pickerStyle(.menu)
                    }
                    
                    // Model Name
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Model Name")
                            .font(.headline)
                        TextField("Model", text: $settings.modelName)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 4)
                    
                    // Server URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server URL")
                            .font(.headline)
                        TextField("https://...", text: $settings.serverURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)
                    
                } header: {
                    Label("LLM Settings", systemImage: "brain")
                } footer: {
                    Text("Lower temperature = more focused. Higher = more creative.")
                }
                
                // MARK: - Voice Settings
                Section {
                    // Voice Selection
                    NavigationLink {
                        VoiceSelectionView(selectedVoiceId: $settings.voiceIdentifier)
                    } label: {
                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(currentVoiceName)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Voice Speed
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Speed")
                            Spacer()
                            Text(speedLabel)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.voiceSpeed, in: 0.3...0.65, step: 0.05)
                            .tint(.purple)
                    }
                    
                    // Voice Pitch
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text(pitchLabel)
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $settings.voicePitch, in: 0.75...1.5, step: 0.05)
                            .tint(.purple)
                    }
                    
                    // Test Voice Button
                    Button(action: testVoice) {
                        Label("Test Voice", systemImage: "speaker.wave.2.fill")
                    }
                    
                } header: {
                    Label("Voice", systemImage: "waveform")
                } footer: {
                    Text("Download more voices in Settings → Accessibility → Spoken Content → Voices")
                }
                
                // MARK: - Conversation Settings
                Section {
                    // Interrupt Sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Interrupt Sensitivity")
                            Spacer()
                            Text(String(format: "%.2f", settings.interruptSensitivity))
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $settings.interruptSensitivity, in: 0.05...0.4, step: 0.05)
                            .tint(.purple)
                        Text("Lower = more sensitive to interruptions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Auto Start Listening
                    Toggle(isOn: $settings.autoStartListening) {
                        VStack(alignment: .leading) {
                            Text("Auto Listen After Response")
                            Text("Automatically start listening after AI speaks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.purple)
                    
                } header: {
                    Label("Conversation", systemImage: "bubble.left.and.bubble.right")
                }
                
                // MARK: - Memory Settings
                Section {
                    Toggle(isOn: $settings.enableMemory) {
                        VStack(alignment: .leading) {
                            Text("Enable Memory")
                            Text("Remember conversations across sessions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.green)
                    
                    if settings.enableMemory {
                        Stepper(value: $settings.memoryContextSize, in: 5...30, step: 5) {
                            HStack {
                                Text("Context Messages")
                                Spacer()
                                Text("\(settings.memoryContextSize)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(role: .destructive, action: { showClearMemoryAlert = true }) {
                            Label("Clear All Memory", systemImage: "trash")
                        }
                    }
                    
                } header: {
                    Label("Memory", systemImage: "brain.head.profile")
                } footer: {
                    Text("Memory helps the AI remember your preferences and past conversations.")
                }
                
                // MARK: - Actions
                Section {
                    Button(action: { viewModel.newConversation() }) {
                        Label("New Conversation", systemImage: "plus.bubble")
                    }
                    
                    Button(role: .destructive, action: { showResetAlert = true }) {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Label("Actions", systemImage: "gearshape")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Assistant")
                        Spacer()
                        Text("Nova")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Clear Memory?", isPresented: $showClearMemoryAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    viewModel.clearMemory()
                }
            } message: {
                Text("This will erase all saved conversations. The AI won't remember anything from past chats.")
            }
            .alert("Reset Settings?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    settings.resetToDefaults()
                }
            } message: {
                Text("This will reset all settings to their default values.")
            }
        }
    }
}

#Preview {
    SettingsView(viewModel: ChatViewModel(client: LocalLLMClient(
        baseURL: URL(string: "https://example.com")!,
        endpointPath: "/v1/chat/completions"
    )))
}

// MARK: - Voice Selection View

struct VoiceSelectionView: View {
    @Binding var selectedVoiceId: String
    @Environment(\.dismiss) private var dismiss
    
    private let synthesizer = AVSpeechSynthesizer()
    
    // Group voices by language
    private var voicesByLanguage: [(String, [AVSpeechSynthesisVoice])] {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        var grouped: [String: [AVSpeechSynthesisVoice]] = [:]
        
        for voice in voices {
            let langCode = String(voice.language.prefix(2))
            let langName = Locale.current.localizedString(forLanguageCode: langCode) ?? langCode
            grouped[langName, default: []].append(voice)
        }
        
        // Sort with English first, then alphabetically
        return grouped.sorted { lhs, rhs in
            if lhs.key == "English" { return true }
            if rhs.key == "English" { return false }
            return lhs.key < rhs.key
        }
    }
    
    var body: some View {
        List {
            // Default option
            Section {
                Button(action: { selectedVoiceId = "" }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("System Default")
                                .foregroundColor(.primary)
                            Text("Uses the best available voice")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedVoiceId.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            // Voices grouped by language
            ForEach(voicesByLanguage, id: \.0) { language, voices in
                Section(header: Text(language)) {
                    ForEach(voices, id: \.identifier) { voice in
                        VoiceRow(
                            voice: voice,
                            isSelected: selectedVoiceId == voice.identifier,
                            onSelect: { selectedVoiceId = voice.identifier },
                            onPreview: { previewVoice(voice) }
                        )
                    }
                }
            }
        }
        .navigationTitle("Select Voice")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func previewVoice(_ voice: AVSpeechSynthesisVoice) {
        let utterance = AVSpeechUtterance(string: "Hello! This is how I sound.")
        utterance.voice = voice
        utterance.rate = 0.5
        
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        synthesizer.stopSpeaking(at: .immediate)
        synthesizer.speak(utterance)
    }
}

struct VoiceRow: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(voice.name)
                                .foregroundColor(.primary)
                            
                            if voice.quality == .enhanced {
                                Text("Enhanced")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        Text(voiceDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onPreview) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var voiceDescription: String {
        let locale = Locale(identifier: voice.language)
        let region = locale.region?.identifier ?? ""
        let regionName = Locale.current.localizedString(forRegionCode: region) ?? region
        
        var desc = regionName
        if voice.quality == .enhanced {
            desc += " • Higher quality"
        }
        return desc
    }
}

