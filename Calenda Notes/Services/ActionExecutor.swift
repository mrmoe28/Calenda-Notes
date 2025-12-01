//
//  ActionExecutor.swift
//  Calenda Notes
//

import Foundation
import UIKit
import EventKit
import Combine

@MainActor
final class ActionExecutor: ObservableObject {
    private let calendarService = CalendarService()
    private let webSearch = WebSearchService()
    private let eventStore = EKEventStore()
    private let weatherService = WeatherServiceImpl()
    private let contactsService = ContactsService()
    
    // MARK: - Calendar Actions
    
    func getCalendarEvents(days: Int = 7) async -> String {
        if !calendarService.isAuthorized {
            let granted = await calendarService.requestAccess()
            if !granted {
                return "❌ Calendar access denied. Please enable in Settings."
            }
        }
        
        let events = calendarService.getUpcomingEvents(days: days)
        if events.isEmpty {
            return "📅 No upcoming events in the next \(days) days."
        }
        return "📅 Upcoming Events:\n" + calendarService.formatEventsForLLM(events)
    }
    
    func getTodayEvents() async -> String {
        if !calendarService.isAuthorized {
            let granted = await calendarService.requestAccess()
            if !granted {
                return "❌ Calendar access denied. Please enable in Settings."
            }
        }
        
        let events = calendarService.getTodayEvents()
        if events.isEmpty {
            return "📅 No events scheduled for today."
        }
        return "📅 Today's Events:\n" + calendarService.formatEventsForLLM(events)
    }
    
    func createCalendarEvent(title: String, date: Date, duration: TimeInterval = 3600) async -> String {
        if !calendarService.isAuthorized {
            let granted = await calendarService.requestAccess()
            if !granted {
                return "❌ Calendar access denied. Please enable in Settings."
            }
        }
        
        let endDate = date.addingTimeInterval(duration)
        let success = await calendarService.createEvent(title: title, startDate: date, endDate: endDate)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        if success {
            return "✅ Created event '\(title)' for \(formatter.string(from: date))"
        } else {
            return "❌ Failed to create event"
        }
    }
    
    // MARK: - Reminder Actions
    
    func createReminder(title: String, date: Date?) async -> String {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if status != .fullAccess && status != .authorized {
            do {
                let granted = try await eventStore.requestFullAccessToReminders()
                if !granted {
                    return "❌ Reminder access denied. Please enable in Settings."
                }
            } catch {
                return "❌ Reminder access error: \(error.localizedDescription)"
            }
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        if let date = date {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let alarm = EKAlarm(absoluteDate: date)
            reminder.addAlarm(alarm)
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            if let date = date {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return "✅ Created reminder '\(title)' for \(formatter.string(from: date))"
            }
            return "✅ Created reminder '\(title)'"
        } catch {
            return "❌ Failed to create reminder: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Web Search
    
    func searchWeb(query: String) async -> String {
        do {
            let results = try await webSearch.search(query: query)
            if results.isEmpty {
                return "🔍 No results found for '\(query)'"
            }
            return "🔍 " + webSearch.formatResultsForLLM(results)
        } catch {
            return "❌ Search failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Weather Actions
    
    func getCurrentWeather() async -> String {
        return await weatherService.getCurrentWeather()
    }
    
    func getWeatherForecast(days: Int = 5) async -> String {
        return await weatherService.getWeatherForecast(days: days)
    }
    
    // MARK: - Contacts Actions
    
    func searchContacts(query: String) async -> String {
        return await contactsService.searchContacts(query: query)
    }
    
    func getContact(name: String) async -> String {
        return await contactsService.getContactByName(name)
    }
    
    func createContact(firstName: String, lastName: String?, phone: String?, email: String?) async -> String {
        return await contactsService.createContact(
            firstName: firstName,
            lastName: lastName,
            phone: phone,
            email: email
        )
    }
    
    /// Look up a contact's phone number by name (for call/message integration)
    func lookupContactPhone(name: String) async -> String? {
        if let result = await contactsService.lookupPhoneNumber(for: name) {
            return result.phone
        }
        return nil
    }
    
    /// Call a contact by name
    func callContact(name: String) async -> String {
        if let phone = await lookupContactPhone(name: name) {
            return makeCall(number: phone)
        }
        return "❌ No phone number found for '\(name)'"
    }
    
    /// Message a contact by name
    func messageContact(name: String, body: String) async -> String {
        if let phone = await lookupContactPhone(name: name) {
            return sendMessage(to: phone, body: body)
        }
        return "❌ No phone number found for '\(name)'"
    }
    
    // MARK: - URL/App Actions
    
    func openURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else {
            return "❌ Invalid URL"
        }
        
        UIApplication.shared.open(url)
        return "✅ Opening \(urlString)"
    }
    
    func openMaps(query: String) -> String {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "maps://?q=\(encoded)"
        return openURL(urlString)
    }
    
    func openSettings() -> String {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            return "✅ Opening Settings"
        }
        return "❌ Could not open Settings"
    }
    
    func makeCall(number: String) -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        return openURL("tel://\(cleaned)")
    }
    
    func sendMessage(to number: String, body: String = "") -> String {
        let cleaned = number.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "")
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return openURL("sms:\(cleaned)&body=\(encoded)")
    }
    
    func composeEmail(to: String, subject: String = "", body: String = "") -> String {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return openURL("mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)")
    }
    
    // MARK: - Clipboard
    
    func copyToClipboard(_ text: String) -> String {
        UIPasteboard.general.string = text
        return "✅ Copied to clipboard"
    }
    
    func getClipboard() -> String {
        if let text = UIPasteboard.general.string {
            return "📋 Clipboard: \(text)"
        }
        return "📋 Clipboard is empty"
    }
    
    // MARK: - Device Info
    
    func getDeviceInfo() -> String {
        let device = UIDevice.current
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = device.batteryLevel >= 0 ? Int(device.batteryLevel * 100) : -1
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        
        return """
        📱 Device Info:
        • Name: \(device.name)
        • Model: \(device.model)
        • iOS: \(device.systemVersion)
        • Battery: \(batteryLevel >= 0 ? "\(batteryLevel)%" : "Unknown")
        • Time: \(formatter.string(from: Date()))
        """
    }
    
    // MARK: - Open Apps
    
    func openApp(_ appName: String) -> String {
        let schemes: [String: String] = [
            // Apple Apps
            "calendar": "calshow://",
            "notes": "mobilenotes://",
            "reminders": "x-apple-reminderkit://",
            "photos": "photos-redirect://",
            "music": "music://",
            "podcasts": "podcasts://",
            "news": "applenews://",
            "weather": "weather://",
            "maps": "maps://",
            "camera": "camera://",
            "facetime": "facetime://",
            "clock": "clock-alarm://",
            "health": "x-apple-health://",
            "wallet": "shoebox://",
            "files": "shareddocuments://",
            "books": "ibooks://",
            "app store": "itms-apps://",
            "appstore": "itms-apps://",
            "watch": "itms-watchs://",
            "home": "com.apple.home://",
            "shortcuts": "shortcuts://",
            "voice memos": "voicememos://",
            "calculator": "calc://",
            "compass": "compass://",
            "contacts": "contact://",
            "find my": "findmy://",
            "freeform": "freeform://",
            "fitness": "fitnessapp://",
            "translate": "translate://",
            "tips": "x-apple-tips://",
            "measure": "measure://",
            "magnifier": "magnifier://",
            
            // Popular 3rd Party Apps
            "spotify": "spotify://",
            "youtube": "youtube://",
            "instagram": "instagram://",
            "twitter": "twitter://",
            "x": "twitter://",
            "facebook": "fb://",
            "whatsapp": "whatsapp://",
            "telegram": "tg://",
            "snapchat": "snapchat://",
            "tiktok": "snssdk1128://",
            "linkedin": "linkedin://",
            "reddit": "reddit://",
            "pinterest": "pinterest://",
            "amazon": "com.amazon.mobile.shopping://",
            "netflix": "nflx://",
            "uber": "uber://",
            "lyft": "lyft://",
            "doordash": "doordash://",
            "starbucks": "starbucks://",
            "venmo": "venmo://",
            "paypal": "paypal://",
            "cash app": "cashme://",
            "google maps": "comgooglemaps://",
            "waze": "waze://",
            "zoom": "zoomus://",
            "slack": "slack://",
            "discord": "discord://",
            "notion": "notion://",
            "gmail": "googlegmail://",
            "chrome": "googlechrome://",
            "drive": "googledrive://",
            "docs": "googledocs://",
            "sheets": "googlesheets://",
        ]
        
        let normalized = appName.lowercased().trimmingCharacters(in: .whitespaces)
        
        if let scheme = schemes[normalized], let url = URL(string: scheme) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return "✅ Opening \(appName.capitalized)"
            } else {
                return "❌ \(appName.capitalized) is not installed"
            }
        }
        
        // Try as a direct URL scheme
        if let url = URL(string: "\(normalized)://") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return "✅ Opening \(appName)"
            }
        }
        
        // Search App Store as fallback
        let encoded = normalized.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? normalized
        if let appStoreURL = URL(string: "itms-apps://search?term=\(encoded)") {
            UIApplication.shared.open(appStoreURL)
            return "🔍 Searching App Store for '\(appName)'"
        }
        
        return "❌ Could not find app: \(appName)"
    }
    
    // MARK: - Parse and Execute
    
    func parseAndExecute(action: String, parameters: [String: Any]) async -> String {
        switch action.lowercased() {
        case "get_calendar", "calendar", "events":
            let days = parameters["days"] as? Int ?? 7
            return await getCalendarEvents(days: days)
            
        case "today", "today_events":
            return await getTodayEvents()
            
        case "create_event", "add_event", "schedule":
            guard let title = parameters["title"] as? String else {
                return "❌ Missing event title"
            }
            let date = parameters["date"] as? Date ?? Date().addingTimeInterval(3600)
            let duration = parameters["duration"] as? TimeInterval ?? 3600
            return await createCalendarEvent(title: title, date: date, duration: duration)
            
        case "create_reminder", "remind", "reminder":
            guard let title = parameters["title"] as? String else {
                return "❌ Missing reminder title"
            }
            let date = parameters["date"] as? Date
            return await createReminder(title: title, date: date)
            
        case "search", "web_search", "google":
            guard let query = parameters["query"] as? String else {
                return "❌ Missing search query"
            }
            return await searchWeb(query: query)
            
        case "open_url", "browse":
            guard let url = parameters["url"] as? String else {
                return "❌ Missing URL"
            }
            return openURL(url)
            
        case "open_maps", "maps", "directions":
            guard let query = parameters["query"] as? String else {
                return "❌ Missing location"
            }
            return openMaps(query: query)
            
        case "call", "phone":
            guard let number = parameters["number"] as? String else {
                return "❌ Missing phone number"
            }
            return makeCall(number: number)
            
        case "message", "sms", "text":
            guard let number = parameters["number"] as? String else {
                return "❌ Missing phone number"
            }
            let body = parameters["body"] as? String ?? ""
            return sendMessage(to: number, body: body)
            
        case "email":
            guard let to = parameters["to"] as? String else {
                return "❌ Missing email address"
            }
            let subject = parameters["subject"] as? String ?? ""
            let body = parameters["body"] as? String ?? ""
            return composeEmail(to: to, subject: subject, body: body)
            
        case "copy", "clipboard":
            guard let text = parameters["text"] as? String else {
                return "❌ Missing text to copy"
            }
            return copyToClipboard(text)
            
        case "paste", "get_clipboard":
            return getClipboard()
            
        case "settings":
            return openSettings()
            
        case "device_info", "info":
            return getDeviceInfo()
            
        case "open_app", "open", "launch":
            guard let app = parameters["app"] as? String else {
                return "❌ Missing app name"
            }
            return openApp(app)
            
        // Weather actions
        case "weather", "current_weather", "get_weather":
            return await getCurrentWeather()
            
        case "forecast", "weather_forecast":
            let days = parameters["days"] as? Int ?? 5
            return await getWeatherForecast(days: days)
            
        // Contacts actions
        case "find_contact", "search_contact", "lookup_contact":
            guard let query = parameters["query"] as? String ?? parameters["name"] as? String else {
                return "❌ Missing contact name"
            }
            return await searchContacts(query: query)
            
        case "get_contact":
            guard let name = parameters["name"] as? String else {
                return "❌ Missing contact name"
            }
            return await getContact(name: name)
            
        case "create_contact", "add_contact":
            guard let firstName = parameters["first_name"] as? String ?? parameters["name"] as? String else {
                return "❌ Missing first name"
            }
            let lastName = parameters["last_name"] as? String
            let phone = parameters["phone"] as? String
            let email = parameters["email"] as? String
            return await createContact(firstName: firstName, lastName: lastName, phone: phone, email: email)
            
        case "call_contact":
            guard let name = parameters["name"] as? String else {
                return "❌ Missing contact name"
            }
            return await callContact(name: name)
            
        case "message_contact", "text_contact":
            guard let name = parameters["name"] as? String else {
                return "❌ Missing contact name"
            }
            let body = parameters["body"] as? String ?? ""
            return await messageContact(name: name, body: body)
            
        default:
            return "❓ Unknown action: \(action)"
        }
    }
}

