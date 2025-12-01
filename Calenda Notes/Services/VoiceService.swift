//
//  VoiceService.swift
//  Calenda Notes
//

import Foundation
import AVFoundation
import Speech
import Combine

// Notification for interrupt detection
extension Notification.Name {
    static let voiceInterruptDetected = Notification.Name("voiceInterruptDetected")
}

@MainActor
final class VoiceService: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var isSpeaking = false
    @Published var transcribedText = ""
    @Published var audioLevel: Float = 0
    @Published var errorMessage: String?
    @Published var wasInterrupted = false
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let synthesizer = AVSpeechSynthesizer()
    
    private var silenceTimer: Timer?
    private var onSpeechComplete: ((String) -> Void)?
    
    // Interrupt detection
    private var interruptMonitoringEnabled = false
    private var interruptAudioLevel: Float = 0
    private let interruptThreshold: Float = 0.15 // Sensitivity for detecting user speech
    private var interruptDetectionTimer: Timer?
    
    override init() {
        super.init()
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        synthesizer.delegate = self
    }
    
    // MARK: - Permissions
    
    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        
        guard speechStatus else {
            errorMessage = "Speech recognition not authorized"
            return false
        }
        
        // Request microphone permission
        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else {
            errorMessage = "Microphone access not authorized"
            return false
        }
        
        return true
    }
    
    // MARK: - Speech Recognition
    
    func startListening(onComplete: @escaping (String) -> Void) {
        guard !isListening else { return }
        
        self.onSpeechComplete = onComplete
        transcribedText = ""
        
        // Configure audio session
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }
        
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for visualization
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData?[i] ?? 0)
            }
            let average = sum / Float(frameLength)
            
            DispatchQueue.main.async {
                self?.audioLevel = min(average * 50, 1.0)
            }
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    // Reset silence timer - faster detection (1.2 seconds of silence)
                    self.silenceTimer?.invalidate()
                    self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { _ in
                        Task { @MainActor in
                            if self.isListening && !self.transcribedText.isEmpty {
                                self.stopListening()
                            }
                        }
                    }
                }
            }
            
            if error != nil || result?.isFinal == true {
                DispatchQueue.main.async {
                    if !self.transcribedText.isEmpty {
                        self.stopListening()
                    }
                }
            }
        }
        
        // Start audio engine
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            errorMessage = "Audio engine error: \(error.localizedDescription)"
        }
    }
    
    func stopListening() {
        guard isListening else { return }
        
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        
        isListening = false
        audioLevel = 0
        
        // Call completion with transcribed text
        if !transcribedText.isEmpty {
            onSpeechComplete?(transcribedText)
        }
    }
    
    // MARK: - Text to Speech
    
    func speak(_ text: String, onComplete: (() -> Void)? = nil) {
        // Stop any ongoing speech and listening
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Stop listening before speaking to avoid conflicts
        if isListening {
            stopListening()
        }
        
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Use playback category for clearer audio output
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("🔊 Audio session configured for playback")
        } catch {
            print("❌ Audio session error: \(error)")
            errorMessage = "Audio error: \(error.localizedDescription)"
        }
        
        // Get settings from UserDefaults (thread-safe)
        let savedVoiceId = UserDefaults.standard.string(forKey: "voice_identifier") ?? ""
        let savedSpeed = UserDefaults.standard.double(forKey: "voice_speed")
        let savedPitch = UserDefaults.standard.double(forKey: "voice_pitch")
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = savedSpeed > 0 ? Float(savedSpeed) : 0.52
        utterance.pitchMultiplier = savedPitch > 0 ? Float(savedPitch) : 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.0  // No delay before speaking
        utterance.postUtteranceDelay = 0.0 // No delay after speaking
        
        // Use saved voice or find a good default
        if !savedVoiceId.isEmpty, let savedVoice = AVSpeechSynthesisVoice(identifier: savedVoiceId) {
            utterance.voice = savedVoice
            print("🎙️ Using saved voice: \(savedVoice.name)")
        } else {
            // Find best available English voice (prefer enhanced/premium voices)
            let voices = AVSpeechSynthesisVoice.speechVoices()
            let englishVoices = voices.filter { $0.language.starts(with: "en") }
            
            // Prefer premium/enhanced voices
            let premiumVoice = englishVoices.first { $0.quality == .enhanced }
            let defaultVoice = premiumVoice ?? englishVoices.first { $0.language == "en-US" } ?? AVSpeechSynthesisVoice(language: "en-US")
            
            utterance.voice = defaultVoice
            print("🎙️ Using default voice: \(defaultVoice?.name ?? "system")")
        }
        
        wasInterrupted = false
        isSpeaking = true
        self.speakCompletion = onComplete
        
        print("🔊 Starting speech: \"\(text.prefix(50))...\"")
        synthesizer.speak(utterance)
    }
    
    private var speakCompletion: (() -> Void)?
    
    func stopSpeaking() {
        stopInterruptMonitoring()
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func stopAll() {
        stopListening()
        stopSpeaking()
    }
    
    // MARK: - Interrupt Detection
    
    private func startInterruptMonitoring() {
        guard !interruptMonitoringEnabled else { return }
        interruptMonitoringEnabled = true
        
        // Use a separate audio tap to monitor mic input while speaking
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
            
            // Install tap for monitoring voice input
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Remove existing tap if any
            inputNode.removeTap(onBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                guard let self = self else { return }
                
                // Calculate audio level
                let channelData = buffer.floatChannelData?[0]
                let frameLength = Int(buffer.frameLength)
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += abs(channelData?[i] ?? 0)
                }
                let average = sum / Float(frameLength)
                let normalizedLevel = min(average * 50, 1.0)
                
                DispatchQueue.main.async {
                    self.interruptAudioLevel = normalizedLevel
                    
                    // Detect if user is speaking (audio above threshold)
                    if self.isSpeaking && normalizedLevel > self.interruptThreshold {
                        self.handleInterrupt()
                    }
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
        } catch {
            print("Interrupt monitoring error: \(error)")
        }
    }
    
    private func stopInterruptMonitoring() {
        guard interruptMonitoringEnabled else { return }
        interruptMonitoringEnabled = false
        interruptDetectionTimer?.invalidate()
        interruptDetectionTimer = nil
        
        if audioEngine.isRunning && !isListening {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
    
    private func handleInterrupt() {
        guard isSpeaking else { return }
        
        print("🎤 User interrupt detected!")
        wasInterrupted = true
        
        // Stop speaking immediately
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        stopInterruptMonitoring()
        
        // Notify that we were interrupted - the view will handle starting to listen
        NotificationCenter.default.post(name: .voiceInterruptDetected, object: nil)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.speakCompletion?()
            self.speakCompletion = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}

