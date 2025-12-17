import Foundation
import Combine
import EventKit

// MARK: - Reminder Error
enum ReminderError: LocalizedError {
    case notFound
    case eventKitNotAuthorized

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Reminder not found"
        case .eventKitNotAuthorized:
            return "Not authorized to access Reminders"
        }
    }
}

@MainActor
class ReminderViewModel: ObservableObject {
    @Published var reminders: [Reminder] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedStatus: ReminderStatus? = nil
    @Published var selectedDateRange: (start: Date, end: Date)? = nil
    @Published var includeEventKitReminders: Bool = true // Toggle to include iOS Reminders
    
    private let apiService = APIService()
    private let eventKitManager = EventKitReminderManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("🔔 ReminderViewModel: Initializing...")
    }
    
    // MARK: - Load Reminders
    
    func loadReminders() async {
        await loadReminders(status: selectedStatus)
    }
    
    func loadReminders(status: ReminderStatus?) async {
        isLoading = true
        errorMessage = nil
        
        var allReminders: [Reminder] = []
        
        // Load from backend API
        do {
            let apiReminders = try await apiService.getReminders(status: status)
            allReminders.append(contentsOf: apiReminders)
            print("✅ ReminderViewModel: Loaded \(apiReminders.count) reminders from backend")
        } catch {
            print("⚠️ ReminderViewModel: Failed to load reminders from backend: \(error.localizedDescription)")
            // Don't set errorMessage here - continue to try EventKit
        }
        
        // Load from EventKit (iOS Reminders app) if enabled and authorized
        if includeEventKitReminders && eventKitManager.isAuthorized {
            do {
                let ekReminders = try await eventKitManager.fetchAllRemindersFromAllCalendars()
                let convertedReminders = ekReminders.compactMap { eventKitManager.convertToReminder($0) }
                
                // Filter by status if needed
                let filteredReminders = convertedReminders.filter { reminder in
                    if let status = status {
                        return reminder.status == status
                    }
                    return true
                }
                
                // Only add EventKit reminders that aren't already in the backend list
                // (to avoid duplicates - backend reminders are the source of truth)
                let backendIds = Set(allReminders.map { $0.id })
                let uniqueEventKitReminders = filteredReminders.filter { !backendIds.contains($0.id) }
                
                allReminders.append(contentsOf: uniqueEventKitReminders)
                print("✅ ReminderViewModel: Loaded \(uniqueEventKitReminders.count) unique reminders from EventKit")
            } catch {
                print("⚠️ ReminderViewModel: Failed to load reminders from EventKit: \(error.localizedDescription)")
            }
        }
        
        // Sort all reminders
        reminders = allReminders.sorted { reminder1, reminder2 in
            // Sort by due date, then by priority
            if reminder1.dueDate != reminder2.dueDate {
                return reminder1.dueDate < reminder2.dueDate
            }
            let priority1 = reminder1.priority?.rawValue ?? "low"
            let priority2 = reminder2.priority?.rawValue ?? "low"
            let priorityOrder: [String: Int] = ["urgent": 0, "high": 1, "medium": 2, "low": 3]
            return (priorityOrder[priority1] ?? 4) < (priorityOrder[priority2] ?? 4)
        }
        
        selectedStatus = status
        isLoading = false
        print("✅ ReminderViewModel: Loaded \(reminders.count) total reminders (backend + EventKit)")
    }
    
    func loadRemindersInRange(startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        selectedDateRange = (start: startDate, end: endDate)
        
        do {
            let fetched = try await apiService.getRemindersInRange(startDate: startDate, endDate: endDate)
            reminders = fetched.sorted { $0.dueDate < $1.dueDate }
            isLoading = false
            print("✅ ReminderViewModel: Loaded \(reminders.count) reminders in range")
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ ReminderViewModel: Failed to load reminders in range: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Reminder
    
    func createReminder(_ request: ReminderRequest, syncToEventKit: Bool = false) async throws -> Reminder {
        let reminder = try await apiService.createReminder(request)
        
        // Sync to EventKit if requested and authorized
        if syncToEventKit && eventKitManager.isAuthorized {
            do {
                try await eventKitManager.syncReminderToEventKit(reminder)
            } catch {
                print("⚠️ ReminderViewModel: Failed to sync to EventKit: \(error.localizedDescription)")
            }
        }
        
        await loadReminders() // Refresh list
        return reminder
    }
    
    // MARK: - Update Reminder
    
    func updateReminder(id: Int64, request: ReminderRequest) async throws -> Reminder {
        let reminder = try await apiService.updateReminder(id: id, request: request)
        await loadReminders() // Refresh list
        return reminder
    }
    
    // MARK: - Complete Reminder

    func completeReminder(id: Int64) async throws -> Reminder {
        // Check if this is an EventKit-only reminder (negative ID)
        if id < 0 {
            // Find the reminder and complete it via EventKit
            guard let reminder = reminders.first(where: { $0.id == id }) else {
                throw ReminderError.notFound
            }

            // Complete in EventKit
            try await completeEventKitReminder(reminder)

            // Return updated reminder
            var completedReminder = reminder
            completedReminder = Reminder(
                id: reminder.id,
                userId: reminder.userId,
                title: reminder.title,
                description: reminder.description,
                dueDate: reminder.dueDate,
                reminderTime: reminder.reminderTime,
                isCompleted: true,
                priority: reminder.priority,
                status: .completed,
                eventId: reminder.eventId,
                recurrenceRule: reminder.recurrenceRule,
                snoozeUntil: reminder.snoozeUntil,
                notificationEnabled: reminder.notificationEnabled,
                notificationSound: reminder.notificationSound,
                createdAt: reminder.createdAt,
                updatedAt: Date(),
                completedAt: Date()
            )

            await loadReminders() // Refresh list
            return completedReminder
        }

        // Backend reminder - use API
        let reminder = try await apiService.completeReminder(id: id)
        await loadReminders() // Refresh list
        return reminder
    }

    /// Completes an EventKit reminder directly
    private func completeEventKitReminder(_ reminder: Reminder) async throws {
        guard eventKitManager.isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }

        // We need to find and complete the actual EKReminder
        // Fetch all reminders and find the matching one by title and date
        let ekReminders = try await eventKitManager.fetchAllRemindersFromAllCalendars()

        guard let ekReminder = ekReminders.first(where: { ek in
            ek.title == reminder.title
        }) else {
            throw ReminderError.notFound
        }

        // Mark as complete
        ekReminder.isCompleted = true
        ekReminder.completionDate = Date()

        // Save to EventKit
        let eventStore = EKEventStore()
        try eventStore.save(ekReminder, commit: true)
        print("✅ ReminderViewModel: Completed EventKit reminder: \(reminder.title)")
    }
    
    // MARK: - Snooze Reminder

    func snoozeReminder(id: Int64, until: Date) async throws -> Reminder {
        // Check if this is an EventKit-only reminder (negative ID)
        if id < 0 {
            // Find the reminder and snooze it via EventKit
            guard let reminder = reminders.first(where: { $0.id == id }) else {
                throw ReminderError.notFound
            }

            // Snooze in EventKit (update the due date)
            try await snoozeEventKitReminder(reminder, until: until)

            // Return updated reminder
            let snoozedReminder = Reminder(
                id: reminder.id,
                userId: reminder.userId,
                title: reminder.title,
                description: reminder.description,
                dueDate: until,
                reminderTime: reminder.reminderTime,
                isCompleted: reminder.isCompleted,
                priority: reminder.priority,
                status: .snoozed,
                eventId: reminder.eventId,
                recurrenceRule: reminder.recurrenceRule,
                snoozeUntil: until,
                notificationEnabled: reminder.notificationEnabled,
                notificationSound: reminder.notificationSound,
                createdAt: reminder.createdAt,
                updatedAt: Date(),
                completedAt: reminder.completedAt
            )

            await loadReminders() // Refresh list
            return snoozedReminder
        }

        // Backend reminder - use API
        let reminder = try await apiService.snoozeReminder(id: id, until: until)
        await loadReminders() // Refresh list
        return reminder
    }

    /// Snoozes an EventKit reminder directly by updating its due date
    private func snoozeEventKitReminder(_ reminder: Reminder, until: Date) async throws {
        guard eventKitManager.isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }

        // Fetch all reminders and find the matching one by title
        let ekReminders = try await eventKitManager.fetchAllRemindersFromAllCalendars()

        guard let ekReminder = ekReminders.first(where: { ek in
            ek.title == reminder.title
        }) else {
            throw ReminderError.notFound
        }

        // Update the due date and alarm
        let calendar = Calendar.current
        ekReminder.dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: until)

        // Update or add alarm
        ekReminder.alarms?.removeAll()
        ekReminder.addAlarm(EKAlarm(absoluteDate: until))

        // Save to EventKit
        let eventStore = EKEventStore()
        try eventStore.save(ekReminder, commit: true)
        print("✅ ReminderViewModel: Snoozed EventKit reminder: \(reminder.title) until \(until)")
    }
    
    // MARK: - Delete Reminder

    func deleteReminder(id: Int64) async throws {
        // Check if this is an EventKit-only reminder (negative ID)
        if id < 0 {
            // Find the reminder and delete it via EventKit
            guard let reminder = reminders.first(where: { $0.id == id }) else {
                throw ReminderError.notFound
            }

            // Delete from EventKit
            try await deleteEventKitReminder(reminder)
            await loadReminders() // Refresh list
            return
        }

        // Backend reminder - use API
        // Get reminder before deleting to sync deletion to EventKit
        let reminder = try? await apiService.getReminder(id: id)

        try await apiService.deleteReminder(id: id)

        // Delete from EventKit if it exists
        if let reminder = reminder, eventKitManager.isAuthorized {
            do {
                try await eventKitManager.deleteReminderFromEventKit(reminderId: reminder.id)
            } catch {
                print("⚠️ ReminderViewModel: Failed to delete from EventKit: \(error.localizedDescription)")
            }
        }

        await loadReminders() // Refresh list
    }

    /// Deletes an EventKit reminder directly
    private func deleteEventKitReminder(_ reminder: Reminder) async throws {
        guard eventKitManager.isAuthorized else {
            throw EventKitReminderError.notAuthorized
        }

        // Fetch all reminders and find the matching one by title
        let ekReminders = try await eventKitManager.fetchAllRemindersFromAllCalendars()

        guard let ekReminder = ekReminders.first(where: { ek in
            ek.title == reminder.title
        }) else {
            throw ReminderError.notFound
        }

        // Delete from EventKit
        let eventStore = EKEventStore()
        try eventStore.remove(ekReminder, commit: true)
        print("✅ ReminderViewModel: Deleted EventKit reminder: \(reminder.title)")
    }
    
    // MARK: - Grouped Reminders
    
    func groupedReminders() -> [String: [Reminder]] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        var groups: [String: [Reminder]] = [:]

        for reminder in reminders where reminder.status == .pending {
            let dueDate = reminder.dueDate
            let dueDateStart = calendar.startOfDay(for: dueDate)

            if dueDateStart < today {
                groups["Catch Up", default: []].append(reminder)
            } else if dueDateStart == today {
                groups["Today", default: []].append(reminder)
            } else if dueDateStart == tomorrow {
                groups["Tomorrow", default: []].append(reminder)
            } else if dueDateStart < nextWeek {
                groups["This Week", default: []].append(reminder)
            } else {
                groups["Coming Up", default: []].append(reminder)
            }
        }

        return groups
    }
    
    // MARK: - Get Reminder by ID
    
    func getReminder(id: Int64) async throws -> Reminder {
        return try await apiService.getReminder(id: id)
    }
    
    // MARK: - Get Reminders for Event
    
    func getRemindersForEvent(eventId: Int64) async throws -> [Reminder] {
        return try await apiService.getRemindersForEvent(eventId: eventId)
    }
    
    // MARK: - Preview Recurring Instances
    
    func previewRecurringInstances(reminderId: Int64, startDate: Date, endDate: Date) async throws -> [Reminder] {
        return try await apiService.previewRecurringInstances(
            reminderId: reminderId,
            startDate: startDate,
            endDate: endDate
        )
    }
}

