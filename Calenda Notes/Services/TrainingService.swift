//
//  TrainingService.swift
//  Calenda Notes
//
//  Custom training for Nova's personality and responses
//

import Foundation

struct TrainedResponse: Codable, Identifiable {
    let id: UUID
    let triggers: [String]  // What user says (lowercased)
    let response: String    // What Nova says
    let action: String?     // Optional action to execute
    
    init(triggers: [String], response: String, action: String? = nil) {
        self.id = UUID()
        self.triggers = triggers.map { $0.lowercased() }
        self.response = response
        self.action = action
    }
}

@MainActor
final class TrainingService: ObservableObject {
    static let shared = TrainingService()
    
    @Published var trainedResponses: [TrainedResponse] = []
    
    private let storageKey = "nova_trained_responses"
    
    private init() {
        loadTraining()
        addDefaultTraining()
    }
    
    // MARK: - Default Training (User's preferences)
    
    private func addDefaultTraining() {
        // Only add defaults if no custom training exists
        if trainedResponses.isEmpty {
            // === GREETINGS ===
            addResponse(
                triggers: ["hi", "hey", "hello", "yo", "sup", "what's up", "whats up", "what's good", "whats good"],
                response: "wassup Moe"
            )
            addResponse(
                triggers: ["good morning", "morning"],
                response: "morning Moe ☀️"
            )
            addResponse(
                triggers: ["good night", "night", "gn"],
                response: "night Moe 🌙"
            )
            
            // === CALENDAR ===
            addResponse(
                triggers: ["open my calendar", "open calendar", "show calendar"],
                response: "im on it",
                action: "open_app|app:calendar"
            )
            
            // === GRATITUDE ===
            addResponse(
                triggers: ["thanks", "thank you", "thx", "ty", "appreciate it"],
                response: "got you 👊"
            )
            addResponse(
                triggers: ["you're the best", "youre the best", "you rock", "love you"],
                response: "no cap, you too Moe 💯"
            )
            
            // === GOODBYES ===
            addResponse(
                triggers: ["bye", "goodbye", "later", "peace", "peace out", "catch you later", "gtg", "gotta go"],
                response: "later Moe ✌️"
            )
            
            // === AFFIRMATIONS ===
            addResponse(
                triggers: ["ok", "okay", "k", "got it", "understood", "alright", "aight"],
                response: "bet 👍"
            )
            addResponse(
                triggers: ["nice", "cool", "awesome", "great", "perfect", "dope", "fire"],
                response: "facts 🔥"
            )
            
            // === QUESTIONS ABOUT NOVA ===
            addResponse(
                triggers: ["who are you", "what are you", "what's your name", "whats your name"],
                response: "im Nova, your AI homie. i run your phone basically"
            )
            addResponse(
                triggers: ["how are you", "how you doing", "how are you doing", "you good"],
                response: "im good Moe, just vibing. what you need?"
            )
            addResponse(
                triggers: ["what can you do", "help", "what do you do"],
                response: "i got you - calendar, apps, weather, contacts, search, calls, texts. just say the word"
            )
            
            // === CASUAL RESPONSES ===
            addResponse(
                triggers: ["lol", "lmao", "haha", "😂", "🤣"],
                response: "lol fr 😂"
            )
            addResponse(
                triggers: ["bruh", "bro", "dude"],
                response: "what's up?"
            )
            addResponse(
                triggers: ["never mind", "nevermind", "nvm", "forget it"],
                response: "aight no worries"
            )
            addResponse(
                triggers: ["wait", "hold on", "hold up", "one sec"],
                response: "im here whenever"
            )
            
            // === POSITIVE VIBES ===
            addResponse(
                triggers: ["you're smart", "youre smart", "smart", "genius"],
                response: "lowkey just doing my job 😎"
            )
            addResponse(
                triggers: ["good job", "nice work", "well done"],
                response: "easy work 💪"
            )
            
            // === APOLOGIES ===
            addResponse(
                triggers: ["sorry", "my bad", "mb"],
                response: "all good Moe, no stress"
            )
            
            saveTraining()
        }
    }
    
    // MARK: - Training Management
    
    func addResponse(triggers: [String], response: String, action: String? = nil) {
        let trained = TrainedResponse(triggers: triggers, response: response, action: action)
        trainedResponses.append(trained)
    }
    
    func removeResponse(_ id: UUID) {
        trainedResponses.removeAll { $0.id == id }
        saveTraining()
    }
    
    func clearAllTraining() {
        trainedResponses = []
        saveTraining()
    }
    
    // MARK: - Matching
    
    func findMatch(for input: String) -> TrainedResponse? {
        let lowercased = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Skip training for time/date questions - let quick actions handle these
        let timeKeywords = ["time", "date", "day is it", "today's date", "what day", "what's the time"]
        for keyword in timeKeywords {
            if lowercased.contains(keyword) {
                return nil
            }
        }
        
        // Exact match first
        for trained in trainedResponses {
            if trained.triggers.contains(lowercased) {
                return trained
            }
        }
        
        // Partial match (input contains trigger)
        for trained in trainedResponses {
            for trigger in trained.triggers {
                if lowercased.contains(trigger) || trigger.contains(lowercased) {
                    return trained
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Persistence
    
    private func saveTraining() {
        if let encoded = try? JSONEncoder().encode(trainedResponses) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadTraining() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TrainedResponse].self, from: data) {
            trainedResponses = decoded
        }
    }
}

