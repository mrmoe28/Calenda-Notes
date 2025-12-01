//
//  TrainingService.swift
//  Calenda Notes
//
//  Custom training for Nova's personality and responses
//

import Foundation
import Combine

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
    private let trainingVersion = 3  // Increment to force refresh
    private let versionKey = "nova_training_version"
    
    private init() {
        // Check if we need to refresh training (version changed)
        let savedVersion = UserDefaults.standard.integer(forKey: versionKey)
        if savedVersion < trainingVersion {
            // Clear old training and add new defaults
            trainedResponses = []
            UserDefaults.standard.removeObject(forKey: storageKey)
            UserDefaults.standard.set(trainingVersion, forKey: versionKey)
        } else {
            loadTraining()
        }
        addDefaultTraining()
    }
    
    /// Force refresh all training data
    func refreshTraining() {
        trainedResponses = []
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.set(trainingVersion, forKey: versionKey)
        addDefaultTraining()
    }
    
    // MARK: - Default Training (User's preferences)
    
    private func addDefaultTraining() {
        // Only add defaults if no custom training exists
        if trainedResponses.isEmpty {
            // Greetings - exact matches only
            addResponse(triggers: ["hi", "hey", "hello", "yo"], response: "wassup Moe")
            addResponse(triggers: ["good morning"], response: "morning Moe")
            addResponse(triggers: ["good night"], response: "night Moe")
            
            // Gratitude
            addResponse(triggers: ["thanks", "thank you"], response: "got you")
            
            // Goodbyes
            addResponse(triggers: ["bye", "later", "peace"], response: "later Moe")
            
            // About Nova
            addResponse(triggers: ["who are you"], response: "im Nova, your AI homie")
            addResponse(triggers: ["how are you"], response: "im good, what you need?")
            
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

