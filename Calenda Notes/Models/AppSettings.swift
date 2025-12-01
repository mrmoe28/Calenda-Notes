//
//  AppSettings.swift
//  Calenda Notes
//
//  Persistent app settings using UserDefaults
//

import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - LLM Settings
    
    @Published var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: "llm_temperature") }
    }
    
    @Published var maxTokens: Int {
        didSet { UserDefaults.standard.set(maxTokens, forKey: "llm_max_tokens") }
    }
    
    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: "llm_model_name") }
    }
    
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "llm_server_url") }
    }
    
    // MARK: - Voice Settings
    
    @Published var voiceSpeed: Double {
        didSet { UserDefaults.standard.set(voiceSpeed, forKey: "voice_speed") }
    }
    
    @Published var voiceIdentifier: String {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: "voice_identifier") }
    }
    
    @Published var voicePitch: Double {
        didSet { UserDefaults.standard.set(voicePitch, forKey: "voice_pitch") }
    }
    
    @Published var interruptSensitivity: Double {
        didSet { UserDefaults.standard.set(interruptSensitivity, forKey: "interrupt_sensitivity") }
    }
    
    @Published var autoStartListening: Bool {
        didSet { UserDefaults.standard.set(autoStartListening, forKey: "auto_start_listening") }
    }
    
    @Published var speakResponsesInChat: Bool {
        didSet { UserDefaults.standard.set(speakResponsesInChat, forKey: "speak_responses_in_chat") }
    }
    
    // MARK: - Memory Settings
    
    @Published var enableMemory: Bool {
        didSet { UserDefaults.standard.set(enableMemory, forKey: "enable_memory") }
    }
    
    @Published var memoryContextSize: Int {
        didSet { UserDefaults.standard.set(memoryContextSize, forKey: "memory_context_size") }
    }
    
    // MARK: - User Profile (Persistent across rebuilds)
    
    @Published var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "user_name") }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved values or use defaults
        // All values persist in UserDefaults - change in Settings, takes effect immediately
        self.temperature = UserDefaults.standard.object(forKey: "llm_temperature") as? Double ?? 0.7
        self.maxTokens = UserDefaults.standard.object(forKey: "llm_max_tokens") as? Int ?? 1024
        self.modelName = UserDefaults.standard.string(forKey: "llm_model_name") ?? ""  // Empty = user must configure
        self.serverURL = UserDefaults.standard.string(forKey: "llm_server_url") ?? ""  // Empty = user must configure
        
        self.voiceSpeed = UserDefaults.standard.object(forKey: "voice_speed") as? Double ?? 0.5
        self.voiceIdentifier = UserDefaults.standard.string(forKey: "voice_identifier") ?? ""
        self.voicePitch = UserDefaults.standard.object(forKey: "voice_pitch") as? Double ?? 1.0
        self.interruptSensitivity = UserDefaults.standard.object(forKey: "interrupt_sensitivity") as? Double ?? 0.15
        self.autoStartListening = UserDefaults.standard.object(forKey: "auto_start_listening") as? Bool ?? true
        self.speakResponsesInChat = UserDefaults.standard.object(forKey: "speak_responses_in_chat") as? Bool ?? true  // ON by default
        
        self.enableMemory = UserDefaults.standard.object(forKey: "enable_memory") as? Bool ?? true
        self.memoryContextSize = UserDefaults.standard.object(forKey: "memory_context_size") as? Int ?? 10
        
        // User profile - persists across app rebuilds!
        self.userName = UserDefaults.standard.string(forKey: "user_name") ?? ""  // Empty = user should set their name
    }
    
    // MARK: - Reset
    
    func resetToDefaults() {
        temperature = 0.7
        maxTokens = 1024
        // Don't reset server/model - user configured these
        voiceSpeed = 0.5
        voiceIdentifier = ""
        voicePitch = 1.0
        interruptSensitivity = 0.15
        autoStartListening = true
        speakResponsesInChat = true
        enableMemory = true
        memoryContextSize = 10
        // Don't reset userName - that's personal
    }
}

// MARK: - Temperature Presets

extension AppSettings {
    enum TemperaturePreset: String, CaseIterable {
        case precise = "Precise"
        case balanced = "Balanced"
        case creative = "Creative"
        case random = "Random"
        
        var value: Double {
            switch self {
            case .precise: return 0.2
            case .balanced: return 0.7
            case .creative: return 1.0
            case .random: return 1.5
            }
        }
        
        var description: String {
            switch self {
            case .precise: return "Focused, deterministic responses"
            case .balanced: return "Good mix of creativity and accuracy"
            case .creative: return "More varied and imaginative"
            case .random: return "Highly unpredictable responses"
            }
        }
        
        static func closest(to value: Double) -> TemperaturePreset {
            return allCases.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? .balanced
        }
    }
}

