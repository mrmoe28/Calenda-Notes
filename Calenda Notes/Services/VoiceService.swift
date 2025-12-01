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
    private var interruptDetectionTimer: Timer?
    private var consecutiveHighLevels: Int = 0  // Require sustained sound to interrupt
    
    /// Get interrupt threshold from settings (lower = more sensitive)
    private var interruptThreshold: Float {
        let saved = UserDefaults.standard.double(forKey: "interrupt_sensitivity")
        return saved > 0 ? Float(saved) : 0.15
    }
    
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
    
    /// Add natural pauses to text for more human-like speech
    private func addNaturalPauses(_ text: String) -> String {
        var result = text
        
        // Add pauses after common transition words/phrases
        let pauseAfter = [
            "so,": "so...",
            "well,": "well...",
            "okay,": "okay...",
            "alright,": "alright...",
            "anyway,": "anyway...",
            "basically,": "basically...",
            "honestly,": "honestly...",
            "actually,": "actually...",
            "like,": "like...",
            "you know,": "you know...",
        ]
        
        for (from, to) in pauseAfter {
            result = result.replacingOccurrences(of: from, with: to, options: .caseInsensitive)
        }
        
        // Add slight pause before "and" in lists (comma before and)
        result = result.replacingOccurrences(of: " and ", with: ", and ")
        
        // Add pause after colons
        result = result.replacingOccurrences(of: ": ", with: ":... ")
        
        // Convert multiple options/items with commas to have breathing room
        // Add pause after numbers in lists like "1." "2." etc
        result = result.replacingOccurrences(of: #"(\d+)\."#, with: "$1...", options: .regularExpression)
        
        // Ensure sentences have proper pauses (add period if missing before new sentence)
        result = result.replacingOccurrences(of: "  ", with: ". ")
        
        return result
    }
    
    func speak(_ text: String, onComplete: (() -> Void)? = nil) {
        // Stop any ongoing speech and listening
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // Stop listening before speaking to avoid conflicts
        if isListening {
            stopListening()
        }
        
        // Configure audio session for playback only (no microphone to avoid conflicts)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("🔊 Audio session configured for playback")
        } catch {
            print("❌ Audio session error: \(error)")
            errorMessage = "Audio error: \(error.localizedDescription)"
        }
        
        // Process text for natural pauses
        let processedText = addNaturalPauses(text)
        
        // Get settings from UserDefaults (thread-safe)
        let savedVoiceId = UserDefaults.standard.string(forKey: "voice_identifier") ?? ""
        let savedSpeed = UserDefaults.standard.double(forKey: "voice_speed")
        let savedPitch = UserDefaults.standard.double(forKey: "voice_pitch")
        
        let utterance = AVSpeechUtterance(string: processedText)
        // Slightly slower default rate for more natural pacing (0.48 instead of 0.52)
        utterance.rate = savedSpeed > 0 ? Float(savedSpeed) : 0.48
        utterance.pitchMultiplier = savedPitch > 0 ? Float(savedPitch) : 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1  // Small pause before speaking
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
        
        // Start monitoring for user interrupts
        startInterruptMonitoring()
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
        // DISABLED: Interrupt monitoring was causing speech to cut out
        // The audio engine conflicts with AVSpeechSynthesizer
        // TODO: Implement using a separate audio unit or volume metering instead
        print("🎤 Interrupt monitoring disabled (causes speech cutoff)")
    }
    
    private func setupInterruptAudioTap() {
        // Disabled - see startInterruptMonitoring()
    }
    
    private func stopInterruptMonitoring() {
        guard interruptMonitoringEnabled else { return }
        interruptMonitoringEnabled = false
        consecutiveHighLevels = 0
        interruptDetectionTimer?.invalidate()
        interruptDetectionTimer = nil
        
        if audioEngine.isRunning && !isListening {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        print("🎤 Interrupt monitoring stopped")
    }
    
    private func handleInterrupt() {
        guard isSpeaking else { return }
        
        print("🎤 User interrupt detected! Stopping speech...")
        wasInterrupted = true
        consecutiveHighLevels = 0
        
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
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 Speech started")
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("🔊 Speech finished normally")
        Task { @MainActor in
            self.isSpeaking = false
            self.stopInterruptMonitoring()
            self.speakCompletion?()
            self.speakCompletion = nil
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("⚠️ Speech was cancelled!")
        Task { @MainActor in
            self.isSpeaking = false
            self.stopInterruptMonitoring()
        }
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("⏸️ Speech paused")
    }
    
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("▶️ Speech continued")
    }
}

