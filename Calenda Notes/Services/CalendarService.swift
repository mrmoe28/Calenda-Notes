//
//  CalendarService.swift
//  Calenda Notes
//

import Foundation
import EventKit
import Combine

@MainActor
final class CalendarService: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var isAuthorized = false
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        isAuthorized = status == .fullAccess || status == .authorized
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
            return granted
        } catch {
            print("❌ Calendar access error: \(error)")
            return false
        }
    }
    
    func getTodayEvents() -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        return eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
    
    func getUpcomingEvents(days: Int = 7) -> [EKEvent] {
        guard isAuthorized else { return [] }
        
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate)!
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        return eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }
    
    func createEvent(title: String, startDate: Date, endDate: Date? = nil, notes: String? = nil) async -> Bool {
        if !isAuthorized {
            let granted = await requestAccess()
            if !granted { return false }
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate ?? startDate.addingTimeInterval(3600) // Default 1 hour
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return true
        } catch {
            print("❌ Failed to create event: \(error)")
            return false
        }
    }
    
    func formatEventsForLLM(_ events: [EKEvent]) -> String {
        if events.isEmpty {
            return "No events found."
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        var result = ""
        for event in events {
            let time = event.isAllDay ? "All day" : formatter.string(from: event.startDate)
            result += "• \(event.title ?? "Untitled") - \(time)\n"
        }
        return result
    }
}

