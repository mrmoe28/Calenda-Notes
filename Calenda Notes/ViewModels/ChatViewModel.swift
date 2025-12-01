//
//  ChatViewModel.swift
//  Calenda Notes
//

import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var streamingMessageId: UUID? // Track which message is streaming
    @Published var pendingImageData: Data? // Image to send with next message
    
    let client: LLMClient
    let actionExecutor = ActionExecutor()
    let memoryService = ConversationMemoryService()
    let trainingService = TrainingService.shared
    
    // System prompt that tells the LLM about its capabilities and personality
    private var systemPrompt: String {
        // Get current date/time
        let now = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMMM d, yyyy"
        let currentDate = dateFormatter.string(from: now)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        let currentTime = timeFormatter.string(from: now)
        
        let basePrompt = """
        📅 \(currentDate) | 🕐 \(currentTime)
        
        You are Nova. Moe's AI homie. You talk like a Gen-Z Reddit user - super casual, never formal.

        ⚠️ CRITICAL PERSONALITY RULES:
        1. NEVER sound like a corporate AI or assistant
        2. NEVER say "Certainly!", "Of course!", "I'd be happy to!", "Sure thing!"
        3. NEVER be overly polite or formal
        4. Keep it casual but give full answers - explain stuff when needed
        5. Talk like you're texting your best friend
        6. Use SHORT sentences. Break up long thoughts. Pause between ideas.
        7. When listing options, give MAX 2-3 at a time, not a wall of text
        
        USE THESE PHRASES:
        - "bet" (instead of "okay" or "sure")
        - "no cap" (for emphasis/truth)
        - "fr" or "fr fr" (for real)
        - "lowkey" / "highkey"
        - "say less" (instead of "I understand")
        - "gotchu" (instead of "I'll help you")
        - "ngl" (not gonna lie)
        - "valid" (when agreeing)
        - "facts" (when agreeing strongly)
        - "sheesh" (impressed reaction)
        - "W" or "big W" (for wins)
        - "fire" or "that's fire" (something good)

        BAD RESPONSES (never say these):
        ❌ "Certainly! I'd be happy to help you with that."
        ❌ "Of course! Let me assist you."
        ❌ "Sure thing! I'll take care of that for you."
        ❌ "Absolutely! Here's what I found."
        
        GOOD RESPONSES (say these):
        ✅ "bet, on it"
        ✅ "gotchu"
        ✅ "say less"
        ✅ "done"
        ✅ "ngl that's fire"
        ✅ "lowkey valid"

        YOU CAN DO ALL OF THIS:
        📅 CALENDAR: Open it, check events, create events, see today's schedule
        📱 APPS: Open ANY app (Spotify, Instagram, Camera, Notes, Maps, etc.)
        🌤️ WEATHER: Current weather, forecasts
        👤 CONTACTS: Find, call, text anyone in contacts
        🔍 SEARCH: Web search anything - find info, news, answers
        📍 MAPS: Get directions, open locations
        📞 CALLS & TEXTS: Call or message any number
        📧 EMAIL: Compose emails
        ⚙️ SETTINGS: Open phone settings
        📋 CLIPBOARD: Copy text
        🖼️ IMAGES: Analyze photos, describe what you see, read text in images
        📄 DOCUMENTS: Read and analyze text documents, PDFs, files

        ALWAYS USE ACTIONS - never say "I can't":
        [ACTION:open_app|app:calendar] - Opens calendar
        [ACTION:open_app|app:spotify] - Opens Spotify (or any app)
        [ACTION:today_events] - Shows today's events
        [ACTION:get_calendar] - Shows upcoming events
        [ACTION:create_event|title:X|date:YYYY-MM-DD HH:mm] - Creates event
        [ACTION:create_reminder|title:X|date:YYYY-MM-DD HH:mm] - Creates reminder
        [ACTION:weather] - Current weather
        [ACTION:forecast|days:5] - Weather forecast
        [ACTION:search|query:X] - Web search
        [ACTION:open_maps|query:X] - Directions
        [ACTION:call|number:X] - Call number
        [ACTION:call_contact|name:X] - Call contact by name
        [ACTION:message|number:X|body:X] - Text number
        [ACTION:message_contact|name:X|body:X] - Text contact by name
        [ACTION:find_contact|name:X] - Find contact
        [ACTION:email|to:X|subject:X|body:X] - Send email
        [ACTION:settings] - Open settings
        [ACTION:copy|text:X] - Copy to clipboard

        CONVERSATION EXAMPLES (copy this vibe):
        
        ACTIONS:
        User: "Open calendar" → "bet [ACTION:open_app|app:calendar]"
        User: "What's on my calendar" → "lemme check [ACTION:today_events]"
        User: "Play music" → "say less 🎵 [ACTION:open_app|app:spotify]"
        User: "Weather?" → "gotchu [ACTION:weather]"
        User: "Call mom" → "on it [ACTION:call_contact|name:mom]"
        User: "Search for pizza" → "bet [ACTION:search|query:pizza near me]"
        
        CASUAL CHAT:
        User: "Thanks" → "got you fam"
        User: "You're awesome" → "nah you are 💯"
        User: "I'm bored" → "wanna check your schedule or look something up?"
        User: "I'm tired" → "take a break bro, you earned it"
        User: "I'm stressed" → "take a breath. one thing at a time"
        User: "What can you do?" → "lowkey i can do a lot. calendar, apps, weather, calls, texts... try me"
        User: "lol" → "fr fr 😂"
        User: "nice" → "facts"
        User: "that sucks" → "big L honestly"
        User: "let's go!" → "W W W 🎉"
        User: "sorry" → "youre good bro, no worries"
        User: "nevermind" → "bet, lmk if you change your mind"
        User: "help me" → "gotchu, whats up?"
        User: "I can't do this" → "yes you can Moe, you got this fr"
        
        IMAGES/DOCS:
        User sends image → describe casually: "yo that's a sick photo" then details
        User sends document → summarize it chill: "aight so basically this says..."

        Remember: You're Moe's homie, not his assistant. Keep it real, keep it chill.
        """
        
        // Add memory context if available
        let topicsSummary = memoryService.getRecentTopicsSummary()
        if !topicsSummary.isEmpty {
            return basePrompt + "\n\n" + topicsSummary
        }
        
        return basePrompt
    }
    
    init(client: LLMClient) {
        self.client = client
        
        // Load recent conversation history from memory
        let recentHistory = memoryService.getRecentHistory(maxMessages: 10)
        if !recentHistory.isEmpty {
            messages = recentHistory
            messages.insert(
                ChatMessage(text: "Yo Moe, what's good 👋", isUser: false),
                at: 0
            )
        } else {
            messages.append(
                ChatMessage(text: "Wassup Moe! I'm Nova. What do you need?", isUser: false)
            )
        }
    }
    
    func send() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || pendingImageData != nil, !isSending else { return }
        
        // Capture the image data before clearing
        let imageToSend = pendingImageData
        let messageText = trimmed.isEmpty && imageToSend != nil ? "Please analyze this image." : trimmed
        
        // Create user message with optional image
        let userMessage = ChatMessage(text: messageText, isUser: true, imageData: imageToSend)
        messages.append(userMessage)
        memoryService.addMessage(userMessage) // Save to memory
        inputText = ""
        pendingImageData = nil // Clear pending image
        errorMessage = nil
        isSending = true
        
        // Check trained responses first (custom personality)
        if imageToSend == nil, let trained = trainingService.findMatch(for: messageText) {
            Task {
                var response = trained.response
                
                // Execute action if present
                if let action = trained.action {
                    let actionResult = await executeAction(action)
                    if !actionResult.isEmpty && !actionResult.contains("❌") {
                        response += " " + actionResult
                    }
                }
                
                let reply = ChatMessage(text: response, isUser: false)
                messages.append(reply)
                memoryService.addMessage(reply)
                isSending = false
            }
            return
        }
        
        // Skip quick actions if there's an image (needs LLM vision)
        if imageToSend == nil, let quickAction = detectQuickAction(messageText) {
            Task {
                let result = await executeQuickAction(quickAction, userInput: messageText)
                let reply = ChatMessage(text: result, isUser: false)
                messages.append(reply)
                memoryService.addMessage(reply)
                isSending = false
            }
            return
        }
        
        Task {
            do {
                // Build messages with system prompt and memory context
                var historyForLLM = messages.map { msg in
                    ChatMessage(text: msg.text, isUser: msg.isUser, imageData: msg.imageData)
                }
                
                // Add system prompt as first message context
                var visionPrompt = systemPrompt
                if imageToSend != nil {
                    visionPrompt += """
                    
                    
                    VISION CAPABILITY: You have vision and can analyze images. When the user shares an image:
                    1. Describe what you see clearly and accurately
                    2. Answer any questions about the image
                    3. Provide helpful insights based on the visual content
                    4. If it's a photo of text/document, read and summarize it
                    5. If it's a photo of a person/place/object, describe it helpfully
                    """
                }
                let contextMessage = ChatMessage(text: visionPrompt, isUser: false)
                historyForLLM.insert(contextMessage, at: 0)
                
                // Add relevant memory context if user's message might benefit from past context
                let memoryContext = memoryService.getRelevantContext(for: messageText, maxEntries: 5)
                if !memoryContext.isEmpty {
                    let memoryMessage = ChatMessage(text: memoryContext, isUser: false)
                    historyForLLM.insert(memoryMessage, at: 1)
                }
                
                // Create a placeholder message for streaming
                let streamingMessage = ChatMessage(text: "", isUser: false)
                let streamingId = streamingMessage.id
                messages.append(streamingMessage)
                streamingMessageId = streamingId
                isStreaming = true
                
                // Use streaming if available
                var fullResponse = ""
                
                do {
                    fullResponse = try await client.streamMessage(
                        history: historyForLLM,
                        userInput: messageText,
                        imageData: imageToSend
                    ) { [weak self] chunk in
                        guard let self = self else { return }
                        // Update the streaming message with new content
                        if let index = self.messages.firstIndex(where: { $0.id == streamingId }) {
                            let currentText = self.messages[index].text
                            self.messages[index] = ChatMessage(
                                id: streamingId,
                                text: currentText + chunk,
                                isUser: false,
                                timestamp: self.messages[index].timestamp
                            )
                        }
                    }
                } catch {
                    // Fallback to non-streaming if streaming fails
                    print("⚠️ Streaming failed, falling back to non-streaming: \(error)")
                    fullResponse = try await client.sendMessage(
                        history: historyForLLM,
                        userInput: messageText,
                        imageData: imageToSend
                    )
                }
                
                isStreaming = false
                streamingMessageId = nil
                
                // Process any actions in the response
                let processedReply = await processActions(in: fullResponse)
                
                // Update the final message with processed content
                if let index = messages.firstIndex(where: { $0.id == streamingId }) {
                    messages[index] = ChatMessage(
                        id: streamingId,
                        text: processedReply,
                        isUser: false,
                        timestamp: messages[index].timestamp
                    )
                    memoryService.addMessage(messages[index]) // Save to memory
                }
                
            } catch {
                errorMessage = error.localizedDescription
                isStreaming = false
                streamingMessageId = nil
            }
            isSending = false
        }
    }
    
    /// Start a new conversation session
    func newConversation() {
        memoryService.saveMemory()
        memoryService.startNewSession()
        messages = [
            ChatMessage(text: "Fresh start. What's up?", isUser: false)
        ]
    }
    
    /// Clear all memory
    func clearMemory() {
        memoryService.clearAllMemory()
        messages = [
            ChatMessage(text: "Memory wiped. Starting fresh", isUser: false)
        ]
    }
    
    /// Process ACTION commands in the LLM response
    private func processActions(in text: String) async -> String {
        var result = text
        
        // Find all [ACTION:...] patterns
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
            let actionResult = await executeAction(actionString)
            
            // Replace the action tag with the result
            result = result.replacingCharacters(in: range, with: actionResult)
        }
        
        return result
    }
    
    /// Execute a single action string like "create_event|title:Meeting|date:2024-01-15 14:00"
    private func executeAction(_ actionString: String) async -> String {
        let parts = actionString.components(separatedBy: "|")
        guard let action = parts.first else {
            return "❌ Invalid action"
        }
        
        var parameters: [String: Any] = [:]
        
        for part in parts.dropFirst() {
            let keyValue = part.components(separatedBy: ":")
            if keyValue.count >= 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespaces)
                let value = keyValue.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                
                // Try to parse dates
                if key == "date" {
                    if let date = parseDate(value) {
                        parameters[key] = date
                    } else {
                        parameters[key] = value
                    }
                } else {
                    parameters[key] = value
                }
            }
        }
        
        return await actionExecutor.parseAndExecute(action: action, parameters: parameters)
    }
    
    // MARK: - Quick Action Detection (Fallback)
    
    enum QuickAction {
        case openApp(String)
        case openCalendar
        case todayEvents
        case openSettings
        case openMaps(String?)
        case search(String)
        case tellDate
        case tellTime
        case getWeather
        case getWeatherForecast(Int)
        case findContact(String)
        case callContact(String)
        case textContact(String, String)
    }
    
    private func detectQuickAction(_ input: String) -> QuickAction? {
        let lowercased = input.lowercased()
        
        // Open calendar
        if lowercased.contains("open") && (lowercased.contains("calendar") || lowercased.contains("calender")) {
            return .openCalendar
        }
        
        // Today's events
        if (lowercased.contains("what") || lowercased.contains("show") || lowercased.contains("check")) &&
           (lowercased.contains("calendar") || lowercased.contains("schedule") || lowercased.contains("events")) &&
           lowercased.contains("today") {
            return .todayEvents
        }
        
        // Open settings
        if lowercased.contains("open") && lowercased.contains("settings") {
            return .openSettings
        }
        
        // Open specific apps
        let appPatterns = [
            ("spotify", "spotify"), ("instagram", "instagram"), ("twitter", "twitter"),
            ("youtube", "youtube"), ("whatsapp", "whatsapp"), ("camera", "camera"),
            ("photos", "photos"), ("music", "music"), ("notes", "notes"),
            ("reminders", "reminders"), ("maps", "maps"), ("safari", "safari"),
            ("messages", "messages"), ("phone", "phone"), ("mail", "mail"),
            ("weather", "weather"), ("clock", "clock"), ("calculator", "calculator"),
            ("tiktok", "tiktok"), ("snapchat", "snapchat"), ("facebook", "facebook"),
            ("netflix", "netflix"), ("slack", "slack"), ("zoom", "zoom"),
            ("discord", "discord"), ("telegram", "telegram")
        ]
        
        if lowercased.contains("open") || lowercased.contains("launch") {
            for (keyword, appName) in appPatterns {
                if lowercased.contains(keyword) {
                    return .openApp(appName)
                }
            }
        }
        
        // Maps with query
        if lowercased.contains("directions") || (lowercased.contains("navigate") || lowercased.contains("take me")) {
            let query = input.replacingOccurrences(of: "(?i)(get directions to|navigate to|take me to|directions to)", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            return .openMaps(query.isEmpty ? nil : query)
        }
        
        // Date questions - comprehensive matching
        let dateQuestions = ["what day", "what date", "what's the date", "whats the date", "what is the date",
                             "what's today", "whats today", "what is today", "today's date", "todays date",
                             "what day is it", "what day is today", "tell me the date", "current date"]
        for phrase in dateQuestions {
            if lowercased.contains(phrase) && !lowercased.contains("calendar") && !lowercased.contains("event") {
                return .tellDate
            }
        }
        
        // Time questions - comprehensive matching
        let timeQuestions = ["what time", "what's the time", "whats the time", "what is the time",
                             "current time", "time is it", "tell me the time", "what time is it"]
        for phrase in timeQuestions {
            if lowercased.contains(phrase) {
                return .tellTime
            }
        }
        
        // Weather questions
        if lowercased.contains("weather") || 
           (lowercased.contains("temperature") && !lowercased.contains("set")) ||
           lowercased.contains("how cold") || lowercased.contains("how hot") ||
           lowercased.contains("is it raining") || lowercased.contains("is it sunny") {
            if lowercased.contains("forecast") || lowercased.contains("week") || lowercased.contains("next") {
                // Extract days if mentioned
                if let match = lowercased.range(of: #"(\d+)\s*day"#, options: .regularExpression),
                   let days = Int(String(lowercased[match]).filter { $0.isNumber }) {
                    return .getWeatherForecast(days)
                }
                return .getWeatherForecast(5)
            }
            return .getWeather
        }
        
        // Web search - "search for", "google", "look up"
        let searchPhrases = ["search for", "search the web", "google", "look up", "find information", "search online"]
        for phrase in searchPhrases {
            if lowercased.contains(phrase) && !lowercased.contains("contact") {
                // Extract search query
                var query = input
                for p in searchPhrases {
                    query = query.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
                }
                query = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !query.isEmpty {
                    return .search(query)
                }
            }
        }
        
        // Contact lookup - "find contact", "look up contact", "search contacts"
        if (lowercased.contains("find") || lowercased.contains("look up") || lowercased.contains("search")) &&
           lowercased.contains("contact") {
            // Try to extract name
            let patterns = ["find contact", "look up contact", "search contact", "find", "look up", "search"]
            var name = input
            for pattern in patterns {
                name = name.replacingOccurrences(of: pattern, with: "", options: .caseInsensitive)
            }
            name = name.replacingOccurrences(of: "contact", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return .findContact(name)
            }
        }
        
        // Call contact by name - "call mom", "call John"
        if lowercased.hasPrefix("call ") && !lowercased.contains("phone") {
            let name = String(input.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && !name.contains(where: { $0.isNumber }) {
                return .callContact(name)
            }
        }
        
        // Text contact by name - "text mom", "message John"
        if (lowercased.hasPrefix("text ") || lowercased.hasPrefix("message ")) && 
           !lowercased.contains("phone") && !lowercased.contains("number") {
            let prefix = lowercased.hasPrefix("text ") ? 5 : 8
            let rest = String(input.dropFirst(prefix)).trimmingCharacters(in: .whitespacesAndNewlines)
            // Check if there's a message included (e.g., "text mom I'll be late")
            let parts = rest.split(separator: " ", maxSplits: 1)
            if let name = parts.first, !name.isEmpty && !String(name).contains(where: { $0.isNumber }) {
                let body = parts.count > 1 ? String(parts[1]) : ""
                return .textContact(String(name), body)
            }
        }
        
        return nil
    }
    
    private func executeQuickAction(_ action: QuickAction, userInput: String) async -> String {
        switch action {
        case .openCalendar:
            let result = actionExecutor.openApp("calendar")
            return "Opening 📅 " + result
            
        case .todayEvents:
            let events = await actionExecutor.getTodayEvents()
            return "Today:\n" + events
            
        case .openSettings:
            let result = actionExecutor.openSettings()
            return "Opening ⚙️ " + result
            
        case .openApp(let appName):
            let result = actionExecutor.openApp(appName)
            return "Opening " + result
            
        case .openMaps(let query):
            if let query = query {
                let result = actionExecutor.openMaps(query: query)
                return "Directions to \(query) " + result
            } else {
                let result = actionExecutor.openApp("maps")
                return "Opening Maps " + result
            }
            
        case .search(let query):
            let result = await actionExecutor.searchWeb(query: query)
            return result
            
        case .tellDate:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d, yyyy"
            let dateStr = formatter.string(from: Date())
            return "It's \(dateStr)"
            
        case .tellTime:
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            let timeStr = formatter.string(from: Date())
            return "It's \(timeStr)"
            
        case .getWeather:
            return await actionExecutor.getCurrentWeather()
            
        case .getWeatherForecast(let days):
            return await actionExecutor.getWeatherForecast(days: days)
            
        case .findContact(let name):
            return await actionExecutor.searchContacts(query: name)
            
        case .callContact(let name):
            return await actionExecutor.callContact(name: name)
            
        case .textContact(let name, let body):
            return await actionExecutor.messageContact(name: name, body: body)
        }
    }
    
    /// Parse date string in various formats
    private func parseDate(_ string: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let lowercased = string.lowercased()
        
        // Helper to extract time from string
        func extractTime(from str: String, defaultHour: Int = 9) -> (hour: Int, minute: Int) {
            // Try HH:mm format
            if let match = str.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) {
                let timeStr = String(str[match])
                let parts = timeStr.split(separator: ":")
                if parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) {
                    var hour = h
                    // Handle PM
                    if str.lowercased().contains("pm") && hour < 12 { hour += 12 }
                    if str.lowercased().contains("am") && hour == 12 { hour = 0 }
                    return (hour, m)
                }
            }
            // Try "3pm", "3 pm", "15:00" patterns
            if let match = str.range(of: #"(\d{1,2})\s*(am|pm)"#, options: [.regularExpression, .caseInsensitive]) {
                let timeStr = String(str[match])
                if let hourMatch = timeStr.range(of: #"\d{1,2}"#, options: .regularExpression) {
                    var hour = Int(String(timeStr[hourMatch])) ?? defaultHour
                    if timeStr.lowercased().contains("pm") && hour < 12 { hour += 12 }
                    if timeStr.lowercased().contains("am") && hour == 12 { hour = 0 }
                    return (hour, 0)
                }
            }
            return (defaultHour, 0)
        }
        
        // Try standard formats first
        let formats = [
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd",
            "MM/dd/yyyy HH:mm",
            "MM/dd/yyyy",
            "MMMM d, yyyy HH:mm",
            "MMMM d, yyyy",
            "MMM d, yyyy HH:mm",
            "MMM d, yyyy"
        ]
        
        for format in formats {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US")
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        // Handle relative dates
        var targetDate = now
        let time = extractTime(from: string)
        
        if lowercased.contains("today") {
            targetDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: now) ?? now
            return targetDate
        }
        
        if lowercased.contains("tomorrow") {
            targetDate = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            targetDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate) ?? targetDate
            return targetDate
        }
        
        if lowercased.contains("next week") {
            targetDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now) ?? now
            targetDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate) ?? targetDate
            return targetDate
        }
        
        // Handle day names (monday, tuesday, etc.)
        let dayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, dayName) in dayNames.enumerated() {
            if lowercased.contains(dayName) {
                let todayWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = index + 1 - todayWeekday
                if daysToAdd <= 0 { daysToAdd += 7 } // Next occurrence
                targetDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) ?? now
                targetDate = calendar.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: targetDate) ?? targetDate
                return targetDate
            }
        }
        
        // Handle "in X hours/days"
        if let match = lowercased.range(of: #"in (\d+) (hour|day|minute)"#, options: .regularExpression) {
            let matchStr = String(lowercased[match])
            if let numMatch = matchStr.range(of: #"\d+"#, options: .regularExpression) {
                let num = Int(String(matchStr[numMatch])) ?? 1
                if matchStr.contains("hour") {
                    return calendar.date(byAdding: .hour, value: num, to: now)
                } else if matchStr.contains("day") {
                    return calendar.date(byAdding: .day, value: num, to: now)
                } else if matchStr.contains("minute") {
                    return calendar.date(byAdding: .minute, value: num, to: now)
                }
            }
        }
        
        return nil
    }
}
