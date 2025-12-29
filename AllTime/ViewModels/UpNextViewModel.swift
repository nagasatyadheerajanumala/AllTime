import Foundation
import SwiftUI
import Combine
import EventKit

@MainActor
class UpNextViewModel: ObservableObject {
    // MARK: - Published Properties

    /// Intelligent suggestions based on calendar gaps and context
    @Published var upNextItems: [UpNextItem] = []

    /// Legacy tasks (for quick add functionality)
    @Published var tasks: [UserTask] = []

    @Published var isLoading = false
    @Published var error: String?
    @Published var summaryMessage: String?
    @Published var totalFreeMinutes = 0
    @Published var meetingCount = 0

    // Legacy counts (kept for backward compatibility)
    @Published var totalCount = 0
    @Published var overdueCount = 0
    @Published var highPriorityCount = 0

    // Quick add
    @Published var quickAddText = ""
    @Published var quickAddDeadline: Date? = nil
    @Published var isAddingTask = false

    // Scheduling
    @Published var isScheduling = false
    @Published var scheduleMessage: String?

    // iOS Reminders integration
    @Published var isRemindersAuthorized = false
    @Published var syncToRemindersEnabled = true // User preference

    private let apiService = APIService()
    private let reminderManager = EventKitReminderManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var hasUpNextItems: Bool {
        !upNextItems.isEmpty
    }

    var pendingTasks: [UserTask] {
        tasks.filter { $0.status == .pending || $0.status == .scheduled }
    }

    var overdueTasks: [UserTask] {
        tasks.filter { $0.isOverdue == true }
    }

    var highPriorityTasks: [UserTask] {
        tasks.filter { $0.priority == .high || $0.priority == .urgent }
    }

    var hasOverdue: Bool {
        overdueCount > 0
    }

    var hasTasks: Bool {
        !tasks.isEmpty
    }

    // MARK: - Load Intelligent Up Next

    /// Load intelligent suggestions based on calendar gaps and context.
    /// This is the primary method for the Up Next section.
    func loadUpNext() async {
        isLoading = true
        error = nil

        // Check reminders authorization on first load
        if !isRemindersAuthorized {
            await checkRemindersAuthorization()
        }

        do {
            let response = try await apiService.getIntelligentUpNext()
            upNextItems = response.items
            totalFreeMinutes = response.totalFreeMinutes ?? 0
            meetingCount = response.meetingCount ?? 0
            summaryMessage = response.message
            print("✅ UpNextViewModel: Loaded \(upNextItems.count) intelligent suggestions")

            // Debug: Log each item's details
            for item in upNextItems {
                print("📋 Item: '\(item.title)' type=\(item.type) primaryAction=\(item.primaryAction ?? "nil") startTime=\(String(describing: item.startTime)) timeLabel=\(item.timeLabel ?? "nil")")
            }

            // NOTE: We no longer auto-sync all items to Reminders on load.
            // Items are only added when the user explicitly taps "Block Time"
        } catch {
            self.error = error.localizedDescription
            print("❌ UpNextViewModel: Failed to load Up Next: \(error)")

            // Fallback to legacy tasks if intelligent endpoint fails
            await loadLegacyTasks()
        }

        isLoading = false
    }

    /// Fallback: Load legacy tasks (for backward compatibility)
    private func loadLegacyTasks() async {
        do {
            let response = try await apiService.getTodaysTasks()
            tasks = response.tasks
            totalCount = response.totalCount
            overdueCount = response.overdueCount
            highPriorityCount = response.highPriorityCount
            print("✅ UpNextViewModel: Fallback - Loaded \(tasks.count) legacy tasks")
        } catch {
            print("❌ UpNextViewModel: Failed to load legacy tasks: \(error)")
        }
    }

    /// Legacy load method (kept for backward compatibility)
    func loadTasks() async {
        await loadUpNext()
    }

    // MARK: - Quick Add

    func quickAdd() async {
        let title = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        isAddingTask = true

        do {
            let newTask = try await apiService.quickAddTask(title: title, deadline: quickAddDeadline)
            tasks.insert(newTask, at: 0)
            totalCount += 1
            quickAddText = ""
            quickAddDeadline = nil  // Reset deadline after adding
            print("✅ UpNextViewModel: Quick added task: \(newTask.title) with deadline: \(newTask.deadline?.description ?? "none")")

            // Sync to iOS Reminders (NOT Calendar)
            await syncTaskToReminders(newTask)

            // Provide haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } catch {
            self.error = error.localizedDescription
            print("❌ UpNextViewModel: Failed to quick add: \(error)")
        }

        isAddingTask = false
    }

    /// Clear the deadline for quick add
    func clearQuickAddDeadline() {
        quickAddDeadline = nil
    }

    // MARK: - Complete Task

    func completeTask(_ task: UserTask, actualDuration: Int? = nil) async {
        guard let taskId = task.id else { return }

        do {
            let updatedTask = try await apiService.completeTask(id: taskId, actualDurationMinutes: actualDuration)

            // Update in list
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index] = updatedTask
            }

            print("✅ UpNextViewModel: Completed task: \(task.title)")

            // Update completion status in iOS Reminders
            await syncTaskToReminders(updatedTask)

            // Provide haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            self.error = error.localizedDescription
            print("❌ UpNextViewModel: Failed to complete task: \(error)")
        }
    }

    // MARK: - Delete Task

    func deleteTask(_ task: UserTask) async {
        guard let taskId = task.id else { return }

        do {
            try await apiService.deleteTask(id: taskId)
            tasks.removeAll { $0.id == taskId }
            totalCount -= 1
            print("✅ UpNextViewModel: Deleted task: \(task.title)")

            // Remove from iOS Reminders
            await removeTaskFromReminders(task)
        } catch {
            self.error = error.localizedDescription
            print("❌ UpNextViewModel: Failed to delete task: \(error)")
        }
    }

    // MARK: - Auto Schedule

    func autoSchedule() async {
        isScheduling = true
        scheduleMessage = nil

        do {
            let response = try await apiService.autoScheduleTasks()
            scheduleMessage = response.message

            // Reload to get updated tasks
            await loadTasks()

            print("✅ UpNextViewModel: \(response.message)")
        } catch {
            self.error = error.localizedDescription
            print("❌ UpNextViewModel: Failed to auto-schedule: \(error)")
        }

        isScheduling = false
    }

    // MARK: - Refresh

    func refresh() async {
        await loadUpNext()
    }

    // MARK: - Sync Up Next Items to Reminders

    /// Syncs intelligent Up Next items to iOS Reminders
    /// Only syncs items that are actionable (gym, lunch, focus work)
    func syncUpNextItemsToReminders() async {
        guard syncToRemindersEnabled && isRemindersAuthorized else { return }

        for item in upNextItems {
            // Only sync actionable items (not generic free time)
            guard item.type != .recreation else { continue }
            await syncUpNextItemToReminders(item)
        }
        print("✅ UpNextViewModel: Synced \(upNextItems.count) Up Next items to iOS Reminders")
    }

    /// Syncs a single Up Next item to iOS Reminders
    private func syncUpNextItemToReminders(_ item: UpNextItem) async {
        guard let startTime = item.startTime else { return }

        // Convert UpNextItem to Reminder
        let reminder = convertUpNextItemToReminder(item)

        do {
            try await reminderManager.syncReminderToEventKit(reminder)
            print("✅ UpNextViewModel: Synced '\(item.title)' to iOS Reminders")
        } catch {
            print("⚠️ UpNextViewModel: Failed to sync Up Next item to Reminders: \(error.localizedDescription)")
        }
    }

    /// Converts an UpNextItem to a Reminder model for EventKit syncing
    private func convertUpNextItemToReminder(_ item: UpNextItem) -> Reminder {
        let dueDate = item.endTime ?? item.startTime ?? Date()
        let reminderTime = item.startTime

        // Map item type to priority
        let priority: ReminderPriority?
        switch item.type {
        case .gym, .focusWork:
            priority = .high
        case .lunch, .walk:
            priority = .medium
        default:
            priority = .low
        }

        return Reminder(
            id: Int64(item.id.hashValue),
            userId: 0,
            title: item.title,
            description: item.description,
            dueDate: dueDate,
            reminderTime: reminderTime,
            isCompleted: false,
            priority: priority,
            status: .pending,
            eventId: nil,
            recurrenceRule: nil,
            snoozeUntil: nil,
            notificationEnabled: true,
            notificationSound: nil,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil
        )
    }

    // MARK: - iOS Reminders Integration

    /// Check and request authorization for iOS Reminders
    func checkRemindersAuthorization() async {
        isRemindersAuthorized = await reminderManager.requestAuthorization()
        print("📱 UpNextViewModel: Reminders authorization: \(isRemindersAuthorized)")
    }

    /// Syncs a task to iOS Reminders app
    /// Tasks are synced as reminders (NOT calendar events)
    func syncTaskToReminders(_ task: UserTask) async {
        guard syncToRemindersEnabled else {
            print("📱 UpNextViewModel: Sync to reminders disabled, skipping")
            return
        }

        if !isRemindersAuthorized {
            print("📱 UpNextViewModel: Not authorized for reminders, requesting...")
            await checkRemindersAuthorization()
        }

        guard isRemindersAuthorized else {
            print("📱 UpNextViewModel: Reminders authorization denied")
            return
        }

        // Convert UserTask to Reminder for EventKit
        let reminder = convertTaskToReminder(task)

        do {
            try await reminderManager.syncReminderToEventKit(reminder)
            print("✅ UpNextViewModel: Synced task '\(task.title)' to iOS Reminders")
        } catch {
            print("⚠️ UpNextViewModel: Failed to sync task to Reminders: \(error.localizedDescription)")
        }
    }

    /// Converts a UserTask to a Reminder model for EventKit syncing
    private func convertTaskToReminder(_ task: UserTask) -> Reminder {
        // Calculate due date based on deadline type
        let dueDate: Date
        if let deadline = task.deadline {
            dueDate = deadline
        } else if let deadlineType = task.deadlineType {
            switch deadlineType {
            case .endOfDay:
                // Set to 11:59 PM today
                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = 23
                components.minute = 59
                dueDate = calendar.date(from: components) ?? Date()
            case .endOfWeek:
                // Set to end of this week (Sunday 11:59 PM)
                let calendar = Calendar.current
                let today = Date()
                let weekday = calendar.component(.weekday, from: today)
                let daysUntilSunday = (8 - weekday) % 7
                var endOfWeek = calendar.date(byAdding: .day, value: daysUntilSunday == 0 ? 7 : daysUntilSunday, to: today) ?? today
                var components = calendar.dateComponents([.year, .month, .day], from: endOfWeek)
                components.hour = 23
                components.minute = 59
                dueDate = calendar.date(from: components) ?? endOfWeek
            case .specificTime:
                dueDate = task.deadline ?? task.targetDate ?? Date()
            case .noDeadline:
                // Set to a week from now as a soft deadline
                dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            }
        } else {
            // Default: end of today
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 23
            components.minute = 59
            dueDate = calendar.date(from: components) ?? Date()
        }

        // Calculate reminder time based on notification preference
        let reminderTime: Date?
        if let minutesBefore = task.notifyMinutesBefore, minutesBefore > 0 {
            reminderTime = dueDate.addingTimeInterval(-Double(minutesBefore * 60))
        } else if let taskReminderTime = task.reminderTime {
            reminderTime = taskReminderTime
        } else {
            // Default: 15 minutes before
            reminderTime = dueDate.addingTimeInterval(-15 * 60)
        }

        // Map task priority to reminder priority
        let reminderPriority: ReminderPriority?
        switch task.priority {
        case .urgent: reminderPriority = .urgent
        case .high: reminderPriority = .high
        case .medium: reminderPriority = .medium
        case .low: reminderPriority = .low
        case .none: reminderPriority = nil
        }

        // Map task status to reminder status
        let reminderStatus: ReminderStatus
        switch task.status {
        case .completed: reminderStatus = .completed
        case .cancelled: reminderStatus = .cancelled
        default: reminderStatus = .pending
        }

        return Reminder(
            id: task.id ?? Int64.random(in: 1...999999),
            userId: 0, // Will be set by the manager
            title: task.title,
            description: task.description,
            dueDate: dueDate,
            reminderTime: reminderTime,
            isCompleted: task.status == .completed,
            priority: reminderPriority,
            status: reminderStatus,
            eventId: nil,
            recurrenceRule: nil,
            snoozeUntil: nil,
            notificationEnabled: task.notifyMinutesBefore != nil || task.isReminder == true,
            notificationSound: nil,
            createdAt: task.createdAt ?? Date(),
            updatedAt: task.updatedAt ?? Date(),
            completedAt: task.completedAt
        )
    }

    /// Removes a task from iOS Reminders
    func removeTaskFromReminders(_ task: UserTask) async {
        guard let taskId = task.id else { return }

        do {
            try await reminderManager.deleteReminderFromEventKit(reminderId: taskId)
            print("✅ UpNextViewModel: Removed task '\(task.title)' from iOS Reminders")
        } catch {
            print("⚠️ UpNextViewModel: Failed to remove task from Reminders: \(error.localizedDescription)")
        }
    }

    /// Syncs all pending tasks to iOS Reminders
    func syncAllTasksToReminders() async {
        guard syncToRemindersEnabled && isRemindersAuthorized else { return }

        for task in pendingTasks {
            await syncTaskToReminders(task)
        }
        print("✅ UpNextViewModel: Synced \(pendingTasks.count) tasks to iOS Reminders")
    }
}
