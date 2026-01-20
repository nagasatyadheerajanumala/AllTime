import Foundation
import EventKit

/// Service for creating calendar events using EventKit
class CalendarService {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()

    private init() {}

    // MARK: - Permission

    /// Request calendar access permission
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("Failed to request calendar access: \(error)")
            return false
        }
    }

    /// Check if we have calendar access
    var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    // MARK: - Create Event

    /// Create a new calendar event
    /// - Parameters:
    ///   - title: Event title
    ///   - startDate: Start time
    ///   - endDate: End time
    ///   - notes: Optional event notes
    ///   - location: Optional event location
    ///   - calendarTitle: Optional calendar to add to (uses default if nil)
    ///   - isAllDay: Whether this is an all-day event
    /// - Returns: True if event was created successfully
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String? = nil,
        location: String? = nil,
        calendarTitle: String? = nil,
        isAllDay: Bool = false
    ) async throws -> Bool {
        // Request access if needed
        if !hasAccess {
            let granted = await requestAccess()
            if !granted {
                throw CalendarError.accessDenied
            }
        }

        // Create the event
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.isAllDay = isAllDay
        if let location = location, !location.isEmpty {
            event.location = location
        }

        // Find calendar
        if let calendarTitle = calendarTitle {
            if let calendar = eventStore.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
                event.calendar = calendar
            } else {
                event.calendar = eventStore.defaultCalendarForNewEvents
            }
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        // Save the event
        try eventStore.save(event, span: .thisEvent)

        print("✅ CalendarService: Created event '\(title)' in device calendar")
        print("   - Start: \(startDate)")
        print("   - End: \(endDate)")
        print("   - All day: \(isAllDay)")
        if let location = location {
            print("   - Location: \(location)")
        }
        return true
    }

    /// Create a focus time event with special formatting
    func createFocusTimeEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        reason: String? = nil
    ) async throws -> Bool {
        let focusTitle = "Focus: \(title)"
        let notes = reason != nil ? "Reason: \(reason!)\n\nCreated by AllTime" : "Created by AllTime"

        return try await createEvent(
            title: focusTitle,
            startDate: startDate,
            endDate: endDate,
            notes: notes
        )
    }

    /// Create a lunch break event
    func createLunchEvent(
        startDate: Date,
        endDate: Date,
        description: String? = nil
    ) async throws -> Bool {
        let notes = description != nil ? "\(description!)\n\nCreated by AllTime" : "Created by AllTime"

        return try await createEvent(
            title: "Lunch Break",
            startDate: startDate,
            endDate: endDate,
            notes: notes
        )
    }
}

// MARK: - Errors

enum CalendarError: Error, LocalizedError {
    case accessDenied
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access was denied. Please enable access in Settings."
        case .eventCreationFailed:
            return "Failed to create calendar event."
        }
    }
}
