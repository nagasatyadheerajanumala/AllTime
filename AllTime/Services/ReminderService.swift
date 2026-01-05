import Foundation
import EventKit

/// Service for creating reminders using EventKit
class ReminderService {
    static let shared = ReminderService()

    private let eventStore = EKEventStore()

    private init() {}

    // MARK: - Permission

    /// Request reminders access permission
    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, *) {
                return try await eventStore.requestFullAccessToReminders()
            } else {
                return try await eventStore.requestAccess(to: .reminder)
            }
        } catch {
            print("Failed to request reminders access: \(error)")
            return false
        }
    }

    /// Check if we have reminders access
    var hasAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    // MARK: - Create Reminder

    /// Create a new reminder
    /// - Parameters:
    ///   - title: Reminder title
    ///   - notes: Optional notes
    ///   - dueDate: When the reminder should fire
    ///   - listTitle: Optional reminders list to add to (uses default if nil)
    /// - Returns: True if reminder was created successfully
    func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date,
        listTitle: String? = nil
    ) async throws -> Bool {
        // Request access if needed
        if !hasAccess {
            let granted = await requestAccess()
            if !granted {
                throw ReminderServiceError.accessDenied
            }
        }

        // Create the reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes

        // Set due date with alarm
        let calendar = Calendar.current
        let dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.dueDateComponents = dueDateComponents

        // Add an alarm at the due date
        let alarm = EKAlarm(absoluteDate: dueDate)
        reminder.addAlarm(alarm)

        // Find reminders list
        if let listTitle = listTitle {
            if let list = eventStore.calendars(for: .reminder).first(where: { $0.title == listTitle }) {
                reminder.calendar = list
            } else {
                reminder.calendar = eventStore.defaultCalendarForNewReminders()
            }
        } else {
            reminder.calendar = eventStore.defaultCalendarForNewReminders()
        }

        // Save the reminder
        try eventStore.save(reminder, commit: true)

        print("ReminderService: Created reminder '\(title)' for \(dueDate)")
        return true
    }

    /// Create a lunch break reminder
    func createLunchReminder(
        title: String = "Time for lunch!",
        description: String? = nil,
        reminderTime: Date
    ) async throws -> Bool {
        let notes = description != nil ? "\(description!)\n\nCreated by AllTime" : "Created by AllTime"

        return try await createReminder(
            title: title,
            notes: notes,
            dueDate: reminderTime
        )
    }
}

// MARK: - Errors

enum ReminderServiceError: Error, LocalizedError {
    case accessDenied
    case reminderCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Reminders access was denied. Please enable access in Settings."
        case .reminderCreationFailed:
            return "Failed to create reminder."
        }
    }
}
