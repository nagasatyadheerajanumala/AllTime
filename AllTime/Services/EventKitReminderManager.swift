import Foundation
import EventKit
import Combine
import UIKit

/// Manages syncing reminders to iOS Reminders app via EventKit
/// Note: EventKit does NOT require a special entitlement or capability
@MainActor
class EventKitReminderManager: ObservableObject {
    static let shared = EventKitReminderManager()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    
    private let eventStore = EKEventStore()
    private let reminderCalendarName = "Clara"
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    /// Checks current authorization status without requesting permission
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
        // iOS 17+ uses .fullAccess instead of .authorized
        if #available(iOS 17.0, *) {
            isAuthorized = authorizationStatus == .fullAccess
        } else {
            isAuthorized = authorizationStatus == .authorized
        }
    }
    
    /// Requests reminder access permission from the user
    /// Returns true if granted, false otherwise
    func requestAuthorization() async -> Bool {
        // Check current status first
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)

        // iOS 17+ uses .fullAccess, older versions use .authorized
        let isCurrentlyAuthorized: Bool
        if #available(iOS 17.0, *) {
            isCurrentlyAuthorized = currentStatus == .fullAccess
        } else {
            isCurrentlyAuthorized = currentStatus == .authorized
        }

        if isCurrentlyAuthorized {
            await MainActor.run {
                isAuthorized = true
                authorizationStatus = currentStatus
            }
            return true
        }

        // Request access - use requestFullAccessToReminders on iOS 17+
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await eventStore.requestAccess(to: .reminder)
            }

            await MainActor.run {
                isAuthorized = granted
                authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            }
            return granted
        } catch {
            print("❌ EventKitReminderManager: Authorization request failed: \(error.localizedDescription)")
            await MainActor.run {
                isAuthorized = false
                authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
            }
            return false
        }
    }
    
    // MARK: - Calendar Management
    
    /// Gets or creates the Clara reminder calendar
    /// Returns nil if not authorized or calendar creation fails
    private func getOrCreateReminderCalendar() -> EKCalendar? {
        guard isAuthorized else {
            return nil
        }
        
        // Try to find existing calendar
        let calendars = eventStore.calendars(for: .reminder)
        if let existing = calendars.first(where: { $0.title == reminderCalendarName }) {
            return existing
        }
        
        // Create new calendar
        let newCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        newCalendar.title = reminderCalendarName
        newCalendar.cgColor = UIColor.systemOrange.cgColor
        
        // Use default reminder source (preferred)
        if let defaultSource = eventStore.defaultCalendarForNewReminders()?.source {
            newCalendar.source = defaultSource
        } else {
            // Fallback to first available source
            newCalendar.source = eventStore.sources.first
        }
        
        guard newCalendar.source != nil else {
            print("❌ EventKitReminderManager: No available source for reminders")
            return nil
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            print("❌ EventKitReminderManager: Failed to create calendar: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Sync Reminder to EventKit
    
    /// Syncs a reminder from the backend to iOS Reminders app
    /// - Parameter reminder: The reminder to sync
    /// - Throws: EventKitReminderError if sync fails
    func syncReminderToEventKit(_ reminder: Reminder) async throws {
        guard isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }
        
        guard let calendar = getOrCreateReminderCalendar() else {
            throw EventKitReminderError.calendarNotFound
        }
        
        // Find or create EventKit reminder
        let ekReminder = try await findExistingReminder(reminderId: reminder.id) ?? {
            let new = EKReminder(eventStore: eventStore)
            new.calendar = calendar
            return new
        }()
        
        // Update reminder properties
        ekReminder.title = reminder.title
        
        // Set notes (description + ID marker)
        var notes = reminder.description ?? ""
        if !notes.isEmpty {
            notes += "\n\n"
        }
        notes += "[Clara ID: \(reminder.id)]"
        ekReminder.notes = notes
        
        // Set due date
        if !reminder.isCompleted {
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.dueDate)
            ekReminder.dueDateComponents = components
            ekReminder.isCompleted = false
        } else {
            ekReminder.dueDateComponents = nil
            ekReminder.isCompleted = true
            ekReminder.completionDate = reminder.completedAt ?? Date()
        }
        
        // Set priority (maps to EKReminder priority values)
        ekReminder.priority = reminder.priority?.ekPriority ?? 0
        
        // Set alarms
        ekReminder.alarms = []
        if !reminder.isCompleted {
            if let reminderTime = reminder.reminderTime {
                ekReminder.addAlarm(EKAlarm(absoluteDate: reminderTime))
            } else if reminder.dueDate > Date() {
                // Default: 15 minutes before due date
                ekReminder.addAlarm(EKAlarm(relativeOffset: -15 * 60))
            }
        }
        
        // Save reminder
        do {
            try eventStore.save(ekReminder, commit: true)
        } catch {
            throw EventKitReminderError.saveFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Find Existing Reminder
    
    /// Finds an existing EventKit reminder by Chrona reminder ID
    private func findExistingReminder(reminderId: Int64) async throws -> EKReminder? {
        guard let calendar = getOrCreateReminderCalendar() else {
            return nil
        }
        
        let predicate = eventStore.predicateForReminders(in: [calendar])
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                // Find reminder with matching Chrona ID in notes
                let matching = reminders?.first { reminder in
                    guard let notes = reminder.notes else { return false }
                    return notes.contains("[Clara ID: \(reminderId)]")
                }
                continuation.resume(returning: matching)
            }
        }
    }
    
    // MARK: - Delete Reminder
    
    /// Deletes a reminder from iOS Reminders app
    /// - Parameter reminderId: The Chrona reminder ID to delete
    /// - Throws: EventKitReminderError if deletion fails
    func deleteReminderFromEventKit(reminderId: Int64) async throws {
        guard isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }
        
        guard let ekReminder = try await findExistingReminder(reminderId: reminderId) else {
            // Reminder not found in EventKit, consider it already deleted
            return
        }
        
        do {
            try eventStore.remove(ekReminder, commit: true)
        } catch {
            throw EventKitReminderError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Fetch Reminders
    
    /// Fetches all reminders from the Chrona calendar
    /// - Returns: Array of EKReminder objects
    func fetchAllReminders() async throws -> [EKReminder] {
        guard isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }
        
        guard let calendar = getOrCreateReminderCalendar() else {
            return []
        }
        
        let predicate = eventStore.predicateForReminders(in: [calendar])
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
    
    /// Fetches all reminders from all calendars (not just Chrona calendar)
    /// This allows users to see reminders they created directly in iOS Reminders app
    /// - Returns: Array of EKReminder objects
    func fetchAllRemindersFromAllCalendars() async throws -> [EKReminder] {
        guard isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }
        
        // Fetch from all reminder calendars
        let allCalendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: allCalendars)
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }
    
    /// Converts an EKReminder to a Reminder model
    /// - Parameter ekReminder: The EventKit reminder to convert
    /// - Returns: A Reminder model, or nil if conversion fails
    func convertToReminder(_ ekReminder: EKReminder) -> Reminder? {
        guard let title = ekReminder.title, !title.isEmpty else {
            return nil
        }
        
        // Extract Chrona ID from notes if present, otherwise generate a negative ID
        var reminderId: Int64 = Int64.random(in: -999999...(-1)) // Negative IDs for EventKit-only reminders
        if let notes = ekReminder.notes,
           let idRange = notes.range(of: "[Clara ID: ") {
            let startIndex = notes.index(idRange.upperBound, offsetBy: 0)
            let endIndex = notes.firstIndex(of: "]") ?? notes.endIndex
            let idString = String(notes[startIndex..<endIndex])
            if let parsedId = Int64(idString) {
                reminderId = parsedId
            }
        }
        
        // Extract description (remove Chrona ID marker if present)
        var description = ekReminder.notes ?? ""
        if let idRange = description.range(of: "[Clara ID: ") {
            description = String(description[..<idRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Get due date
        let dueDate: Date
        if let dueComponents = ekReminder.dueDateComponents,
           let date = Calendar.current.date(from: dueComponents) {
            dueDate = date
        } else {
            // If no due date, use creation date or now
            dueDate = ekReminder.creationDate ?? Date()
        }
        
        // Get reminder time (from first alarm)
        let reminderTime: Date? = ekReminder.alarms?.first?.absoluteDate
        
        // Map priority
        let priority: ReminderPriority?
        switch ekReminder.priority {
        case 0: priority = .low
        case 1: priority = .medium
        case 5: priority = .high
        case 9: priority = .urgent
        default: priority = nil
        }
        
        // Determine status
        let status: ReminderStatus
        if ekReminder.isCompleted {
            status = .completed
        } else {
            status = .pending
        }
        
        return Reminder(
            id: reminderId,
            userId: 0, // EventKit reminders don't have a user ID
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: dueDate,
            reminderTime: reminderTime,
            isCompleted: ekReminder.isCompleted,
            priority: priority,
            status: status,
            eventId: nil,
            recurrenceRule: nil, // EKReminder recurrence is complex, skip for now
            snoozeUntil: nil,
            notificationEnabled: reminderTime != nil,
            notificationSound: nil,
            createdAt: ekReminder.creationDate ?? Date(),
            updatedAt: ekReminder.lastModifiedDate ?? Date(),
            completedAt: ekReminder.completionDate
        )
    }
    
    // MARK: - Batch Sync
    
    /// Syncs multiple reminders to EventKit
    /// Silently continues on individual failures
    func syncAllReminders(_ reminders: [Reminder]) async {
        guard isAuthorized else {
            return
        }
        
        for reminder in reminders {
            do {
                try await syncReminderToEventKit(reminder)
            } catch {
                // Log but continue with other reminders
                print("⚠️ EventKitReminderManager: Failed to sync reminder \(reminder.id): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Errors

enum EventKitReminderError: LocalizedError {
    case notAuthorized
    case calendarNotFound
    case saveFailed(String)
    case deleteFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Reminder access not authorized. Please enable in Settings."
        case .calendarNotFound:
            return "Could not create or find reminder calendar."
        case .saveFailed(let message):
            return "Failed to save reminder: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete reminder: \(message)"
        }
    }
}

// MARK: - ReminderPriority Extension

extension ReminderPriority {
    /// Maps Chrona reminder priority to EKReminder priority
    var ekPriority: Int {
        switch self {
        case .low: return 0      // EKReminderPriorityNone
        case .medium: return 1   // EKReminderPriorityLow
        case .high: return 5     // EKReminderPriorityMedium
        case .urgent: return 9   // EKReminderPriorityHigh
        }
    }
}

