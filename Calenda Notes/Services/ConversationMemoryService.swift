//
//  ConversationMemoryService.swift
//  Calenda Notes
//
//  Persistent memory for conversation history
//

import Foundation
import Combine

struct MemoryEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    var importance: Int // 1-5 scale for relevance
    var tags: [String] // Keywords for context retrieval
    
    init(from message: ChatMessage, importance: Int = 2, tags: [String] = []) {
        self.id = message.id
        self.text = message.text
        self.isUser = message.isUser
        self.timestamp = message.timestamp
        self.importance = importance
        self.tags = tags
    }
}

struct ConversationSession: Codable, Identifiable {
    let id: UUID
    let startDate: Date
    var messages: [MemoryEntry]
    var summary: String?
    
    init(id: UUID = UUID(), startDate: Date = Date(), messages: [MemoryEntry] = [], summary: String? = nil) {
        self.id = id
        self.startDate = startDate
        self.messages = messages
        self.summary = summary
    }
}

@MainActor
final class ConversationMemoryService: ObservableObject {
    @Published var currentSession: ConversationSession
    @Published var pastSessions: [ConversationSession] = []
    
    private let maxMessagesPerSession = 100
    private let maxSessions = 50
    private let fileManager = FileManager.default
    
    private var memoryFileURL: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("conversation_memory.json")
    }
    
    init() {
        self.currentSession = ConversationSession()
        loadMemory()
    }
    
    // MARK: - Save & Load
    
    func saveMemory() {
        var allSessions = pastSessions
        if !currentSession.messages.isEmpty {
            allSessions.insert(currentSession, at: 0)
        }
        
        // Limit total sessions
        if allSessions.count > maxSessions {
            allSessions = Array(allSessions.prefix(maxSessions))
        }
        
        do {
            let data = try JSONEncoder().encode(allSessions)
            try data.write(to: memoryFileURL)
            print("💾 Saved \(allSessions.count) conversation sessions")
        } catch {
            print("❌ Failed to save memory: \(error)")
        }
    }
    
    func loadMemory() {
        guard fileManager.fileExists(atPath: memoryFileURL.path) else {
            print("📂 No existing memory file found")
            return
        }
        
        do {
            let data = try Data(contentsOf: memoryFileURL)
            let sessions = try JSONDecoder().decode([ConversationSession].self, from: data)
            pastSessions = sessions
            print("📖 Loaded \(sessions.count) conversation sessions")
        } catch {
            print("❌ Failed to load memory: \(error)")
        }
    }
    
    // MARK: - Message Management
    
    func addMessage(_ message: ChatMessage) {
        let entry = MemoryEntry(from: message, importance: 2, tags: extractTags(from: message.text))
        currentSession.messages.append(entry)
        
        // Auto-save periodically
        if currentSession.messages.count % 5 == 0 {
            saveMemory()
        }
    }
    
    func startNewSession() {
        if !currentSession.messages.isEmpty {
            pastSessions.insert(currentSession, at: 0)
        }
        currentSession = ConversationSession()
        saveMemory()
    }
    
    // MARK: - Context Retrieval
    
    /// Get relevant context from memory based on the current query
    func getRelevantContext(for query: String, maxEntries: Int = 10) -> String {
        var relevantEntries: [(entry: MemoryEntry, score: Double)] = []
        let queryWords = Set(query.lowercased().split(separator: " ").map(String.init))
        
        // Search current session
        for entry in currentSession.messages {
            let score = calculateRelevance(entry: entry, queryWords: queryWords)
            if score > 0.1 {
                relevantEntries.append((entry, score))
            }
        }
        
        // Search past sessions
        for session in pastSessions.prefix(10) { // Only check recent sessions
            for entry in session.messages {
                let score = calculateRelevance(entry: entry, queryWords: queryWords)
                if score > 0.2 { // Higher threshold for older memories
                    relevantEntries.append((entry, score))
                }
            }
        }
        
        // Sort by relevance and take top entries
        let topEntries = relevantEntries
            .sorted { $0.score > $1.score }
            .prefix(maxEntries)
        
        guard !topEntries.isEmpty else { return "" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        
        var context = "## Relevant memories from past conversations:\n"
        for (entry, _) in topEntries {
            let role = entry.isUser ? "User" : "Assistant"
            let date = formatter.string(from: entry.timestamp)
            context += "[\(date)] \(role): \(entry.text)\n"
        }
        
        return context
    }
    
    /// Get a summary of recent conversation topics for context
    func getRecentTopicsSummary() -> String {
        var topics: [String: Int] = [:]
        
        // Count tag frequencies
        for entry in currentSession.messages {
            for tag in entry.tags {
                topics[tag, default: 0] += 1
            }
        }
        
        for session in pastSessions.prefix(5) {
            for entry in session.messages {
                for tag in entry.tags {
                    topics[tag, default: 0] += 1
                }
            }
        }
        
        let topTopics = topics
            .sorted { $0.value > $1.value }
            .prefix(10)
            .map { $0.key }
        
        if topTopics.isEmpty { return "" }
        
        return "Recent topics discussed: \(topTopics.joined(separator: ", "))"
    }
    
    /// Get full recent history for LLM context window
    func getRecentHistory(maxMessages: Int = 20) -> [ChatMessage] {
        let recentEntries = currentSession.messages.suffix(maxMessages)
        return recentEntries.map { entry in
            ChatMessage(
                id: entry.id,
                text: entry.text,
                isUser: entry.isUser,
                timestamp: entry.timestamp
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func calculateRelevance(entry: MemoryEntry, queryWords: Set<String>) -> Double {
        let entryWords = Set(entry.text.lowercased().split(separator: " ").map(String.init))
        let tagWords = Set(entry.tags.map { $0.lowercased() })
        
        // Word overlap
        let wordOverlap = Double(queryWords.intersection(entryWords).count) / max(Double(queryWords.count), 1)
        
        // Tag match bonus
        let tagMatch = Double(queryWords.intersection(tagWords).count) * 0.3
        
        // Recency bonus (newer = more relevant)
        let daysSinceEntry = Calendar.current.dateComponents([.day], from: entry.timestamp, to: Date()).day ?? 0
        let recencyBonus = max(0, 1.0 - Double(daysSinceEntry) * 0.05)
        
        // Importance bonus
        let importanceBonus = Double(entry.importance) * 0.1
        
        return (wordOverlap + tagMatch) * recencyBonus + importanceBonus
    }
    
    private func extractTags(from text: String) -> [String] {
        var tags: [String] = []
        let lowercased = text.lowercased()
        
        // Common topic keywords
        let topicKeywords = [
            "meeting", "appointment", "calendar", "schedule", "reminder",
            "call", "email", "task", "project", "deadline",
            "birthday", "anniversary", "holiday", "vacation", "travel",
            "doctor", "dentist", "health", "workout", "exercise",
            "shopping", "groceries", "restaurant", "food",
            "work", "office", "client", "presentation",
            "family", "friend", "party", "event",
            "weather", "news", "sports", "music", "movie"
        ]
        
        for keyword in topicKeywords {
            if lowercased.contains(keyword) {
                tags.append(keyword)
            }
        }
        
        // Extract names (capitalized words that aren't at sentence start)
        let words = text.components(separatedBy: .whitespaces)
        for (index, word) in words.enumerated() {
            if index > 0 && word.first?.isUppercase == true && word.count > 2 {
                let cleaned = word.trimmingCharacters(in: .punctuationCharacters)
                if !cleaned.isEmpty {
                    tags.append(cleaned.lowercased())
                }
            }
        }
        
        // Extract dates mentioned
        if lowercased.contains("tomorrow") { tags.append("tomorrow") }
        if lowercased.contains("today") { tags.append("today") }
        if lowercased.contains("next week") { tags.append("next week") }
        if lowercased.contains("monday") || lowercased.contains("tuesday") ||
           lowercased.contains("wednesday") || lowercased.contains("thursday") ||
           lowercased.contains("friday") || lowercased.contains("saturday") ||
           lowercased.contains("sunday") {
            tags.append("weekday")
        }
        
        return Array(Set(tags)) // Remove duplicates
    }
    
    // MARK: - Clear Memory
    
    func clearAllMemory() {
        currentSession = ConversationSession()
        pastSessions = []
        try? fileManager.removeItem(at: memoryFileURL)
        print("🗑️ Cleared all conversation memory")
    }
    
    func clearCurrentSession() {
        currentSession = ConversationSession()
    }
}

