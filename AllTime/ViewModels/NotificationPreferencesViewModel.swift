import Foundation
import Combine
import UserNotifications
import UIKit

/// ViewModel for notification preferences settings view
@MainActor
class NotificationPreferencesViewModel: ObservableObject {
    // MARK: - Observed Services

    @Published var preferencesService = NotificationPreferencesService.shared

    // MARK: - Local State

    @Published var showingPermissionAlert = false
    @Published var testNotificationResult: (success: Bool, message: String)?
    @Published var showingTestResult = false

    // Notification history
    @Published var notificationHistory: [NotificationHistoryEntry] = []
    @Published var notificationStats: NotificationStatsResponse?
    @Published var isLoadingHistory = false
    @Published var isLoadingStats = false

    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Subscribe to preferences service changes
        preferencesService.$preferences
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties (for bindings)

    var notificationsEnabled: Bool {
        get { preferencesService.preferences.notificationsEnabled ?? true }
        set { preferencesService.setNotificationsEnabled(newValue) }
    }

    var morningBriefingEnabled: Bool {
        get { preferencesService.preferences.morningBriefingEnabled ?? true }
        set { preferencesService.setMorningBriefing(enabled: newValue) }
    }

    var eveningSummaryEnabled: Bool {
        get { preferencesService.preferences.eveningSummaryEnabled ?? true }
        set { preferencesService.setEveningSummary(enabled: newValue) }
    }

    var eventRemindersEnabled: Bool {
        get { preferencesService.preferences.eventRemindersEnabled ?? true }
        set { preferencesService.setEventReminders(enabled: newValue) }
    }

    var clashAlertsEnabled: Bool {
        get { preferencesService.preferences.clashAlertsEnabled ?? true }
        set { preferencesService.setClashAlerts(enabled: newValue) }
    }

    var taskRemindersEnabled: Bool {
        get { preferencesService.preferences.taskRemindersEnabled ?? true }
        set { preferencesService.setTaskReminders(enabled: newValue) }
    }

    var proactiveNudgesEnabled: Bool {
        get { preferencesService.preferences.proactiveNudgesEnabled ?? true }
        set { preferencesService.setProactiveNudges(enabled: newValue) }
    }

    var lunchRemindersEnabled: Bool {
        get { preferencesService.preferences.lunchRemindersEnabled ?? false }
        set { preferencesService.setLunchReminders(enabled: newValue) }
    }

    var quietHoursEnabled: Bool {
        get { preferencesService.preferences.quietHoursEnabled ?? true }
        set { preferencesService.setQuietHours(enabled: newValue) }
    }

    var weekendReduced: Bool {
        get { preferencesService.preferences.weekendReduced ?? true }
        set { preferencesService.setWeekendReduced(newValue) }
    }

    var morningBriefingTime: Date {
        get { preferencesService.preferences.morningBriefingTime }
        set {
            var prefs = preferencesService.preferences
            prefs.morningBriefingTime = newValue
            preferencesService.preferences = prefs
            preferencesService.debouncedSave()
        }
    }

    var morningBriefingHour: Int {
        get { preferencesService.preferences.morningBriefingHour ?? 7 }
        set {
            preferencesService.setMorningBriefing(enabled: morningBriefingEnabled, hour: newValue)
        }
    }

    var eveningSummaryTime: Date {
        get { preferencesService.preferences.eveningSummaryTime }
        set {
            var prefs = preferencesService.preferences
            prefs.eveningSummaryTime = newValue
            preferencesService.preferences = prefs
            preferencesService.debouncedSave()
        }
    }

    var eveningSummaryHour: Int {
        get { preferencesService.preferences.eveningSummaryHour ?? 20 }
        set {
            preferencesService.setEveningSummary(enabled: eveningSummaryEnabled, hour: newValue)
        }
    }

    var quietHoursStartTime: Date {
        get { preferencesService.preferences.quietHoursStartTime }
        set {
            var prefs = preferencesService.preferences
            prefs.quietHoursStartTime = newValue
            preferencesService.preferences = prefs
            preferencesService.debouncedSave()
        }
    }

    var quietHoursEndTime: Date {
        get { preferencesService.preferences.quietHoursEndTime }
        set {
            var prefs = preferencesService.preferences
            prefs.quietHoursEndTime = newValue
            preferencesService.preferences = prefs
            preferencesService.debouncedSave()
        }
    }

    var eventReminderMinutes: Int {
        get { preferencesService.preferences.eventReminderMinutes ?? 15 }
        set { preferencesService.setEventReminders(enabled: eventRemindersEnabled, minutesBefore: newValue) }
    }

    var maxNudgesPerDay: Int {
        get { preferencesService.preferences.maxNudgesPerDay ?? 5 }
        set { preferencesService.setRateLimits(maxNudges: newValue) }
    }

    var minMinutesBetween: Int {
        get { preferencesService.preferences.minMinutesBetweenNotifications ?? 30 }
        set { preferencesService.setRateLimits(minMinutesBetween: newValue) }
    }

    // MARK: - Actions

    func onAppear() {
        Task {
            // Service handles rate limiting and prevents overwriting pending changes
            await preferencesService.syncPreferences()
            await checkNotificationPermission()
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self?.showingPermissionAlert = true
                }
            }
        }
    }

    private func checkNotificationPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        if settings.authorizationStatus != .authorized && notificationsEnabled {
            showingPermissionAlert = true
        }
    }

    func sendTestNotification(type: String) {
        Task {
            let result = await preferencesService.sendTestNotification(type: type)
            testNotificationResult = result
            showingTestResult = true
        }
    }

    /// Request push notification registration
    func requestPushRegistration() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("🔔 NotificationPreferencesViewModel: Requested push registration")
                }
            } else {
                DispatchQueue.main.async {
                    self.showingPermissionAlert = true
                }
            }
        }
    }

    // MARK: - History & Stats

    func loadNotificationHistory(days: Int = 7) {
        isLoadingHistory = true
        Task {
            do {
                let response = try await apiService.getNotificationHistory(days: days)
                notificationHistory = response.history
            } catch {
                print("Failed to load notification history: \(error)")
            }
            isLoadingHistory = false
        }
    }

    func loadNotificationStats(days: Int = 30) {
        isLoadingStats = true
        Task {
            do {
                notificationStats = try await apiService.getNotificationStats(days: days)
            } catch {
                print("Failed to load notification stats: \(error)")
            }
            isLoadingStats = false
        }
    }

    // MARK: - Formatting Helpers

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var eventReminderOptions: [(String, Int)] {
        [
            ("5 minutes", 5),
            ("10 minutes", 10),
            ("15 minutes", 15),
            ("30 minutes", 30),
            ("1 hour", 60)
        ]
    }

    var nudgesPerDayOptions: [Int] {
        [1, 2, 3, 5, 8, 10]
    }

    var minMinutesOptions: [(String, Int)] {
        [
            ("15 minutes", 15),
            ("30 minutes", 30),
            ("1 hour", 60),
            ("2 hours", 120)
        ]
    }
}
