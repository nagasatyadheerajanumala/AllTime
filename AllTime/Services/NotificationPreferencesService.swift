import Foundation
import Combine
import UserNotifications

/// Service for managing notification preferences synced with backend.
/// Acts as single source of truth for all notification settings.
@MainActor
class NotificationPreferencesService: ObservableObject {
    static let shared = NotificationPreferencesService()

    // MARK: - Published State

    @Published var preferences: NotificationPreferences = .defaults
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var error: String?
    @Published var lastSyncedAt: Date?
    @Published var isQuietHoursActive = false

    // MARK: - Private

    private let apiService = APIService()
    private var syncTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    /// Tracks if we've done initial sync in this app session
    /// This is on the singleton, so it persists across view recreations
    private var hasInitiallySynced = false

    /// Minimum time between syncs (5 seconds)
    private var lastSyncTime: Date?
    private let minSyncInterval: TimeInterval = 5.0

    private init() {
        // Load cached preferences immediately
        loadCachedPreferences()
    }

    // MARK: - Sync with Backend

    /// Track if we have pending local changes that shouldn't be overwritten
    private var hasPendingChanges: Bool {
        debounceTask != nil || isSaving
    }

    /// Fetch preferences from backend and update local cache
    func syncPreferences() async {
        // Don't sync if we're already loading, saving, or have pending changes
        guard !isLoading && !hasPendingChanges else {
            print("🔔 NotificationPreferencesService: Skipping sync - pending changes or already loading")
            return
        }

        // Rate limit syncs - don't sync more than once per 5 seconds
        if let lastSync = lastSyncTime, Date().timeIntervalSince(lastSync) < minSyncInterval {
            print("🔔 NotificationPreferencesService: Skipping sync - too recent (last sync \(Date().timeIntervalSince(lastSync))s ago)")
            return
        }

        isLoading = true
        error = nil

        // Store current local values in case server returns nulls
        let localPrefs = preferences

        do {
            let serverPrefs = try await apiService.getNotificationPreferences()

            // Merge server values with local fallbacks for any nulls
            var merged = serverPrefs
            if merged.morningBriefingHour == nil { merged.morningBriefingHour = localPrefs.morningBriefingHour }
            if merged.eveningSummaryHour == nil { merged.eveningSummaryHour = localPrefs.eveningSummaryHour }
            if merged.quietHoursStart == nil { merged.quietHoursStart = localPrefs.quietHoursStart }
            if merged.quietHoursEnd == nil { merged.quietHoursEnd = localPrefs.quietHoursEnd }
            if merged.eventReminderMinutes == nil { merged.eventReminderMinutes = localPrefs.eventReminderMinutes }
            if merged.maxNudgesPerDay == nil { merged.maxNudgesPerDay = localPrefs.maxNudgesPerDay }
            if merged.minMinutesBetweenNotifications == nil { merged.minMinutesBetweenNotifications = localPrefs.minMinutesBetweenNotifications }

            preferences = merged
            cachePreferences(merged)
            lastSyncedAt = Date()
            lastSyncTime = Date()
            hasInitiallySynced = true
            print("🔔 NotificationPreferencesService: Synced preferences from backend - morningHour=\(merged.morningBriefingHour ?? -1), eveningHour=\(merged.eveningSummaryHour ?? -1)")
        } catch {
            self.error = error.localizedDescription
            print("🔔 NotificationPreferencesService: Failed to sync - \(error.localizedDescription)")
            // Keep using cached/local preferences on sync failure
        }

        isLoading = false
    }

    /// Force sync from backend (ignores pending changes - use with caution)
    func forceSyncPreferences() async {
        debounceTask?.cancel()
        debounceTask = nil
        isLoading = false
        isSaving = false
        await syncPreferences()
    }

    /// Save current preferences to backend
    func savePreferences() async {
        guard !isSaving else { return }

        isSaving = true
        error = nil

        // Store ALL current values before save (in case server returns nulls)
        let currentPrefs = preferences
        let currentMorningHour = preferences.morningBriefingHour
        let currentEveningHour = preferences.eveningSummaryHour
        let currentQuietStart = preferences.quietHoursStart
        let currentQuietEnd = preferences.quietHoursEnd

        print("🔔 NotificationPreferencesService: Saving - morningHour=\(currentMorningHour ?? -1), eveningHour=\(currentEveningHour ?? -1)")

        do {
            let updated = try await apiService.updateNotificationPreferences(preferences)

            print("🔔 NotificationPreferencesService: Server returned - morningHour=\(updated.morningBriefingHour ?? -1), eveningHour=\(updated.eveningSummaryHour ?? -1)")

            // Merge: keep local values if server returned nil
            var merged = updated
            if merged.morningBriefingHour == nil { merged.morningBriefingHour = currentMorningHour }
            if merged.eveningSummaryHour == nil { merged.eveningSummaryHour = currentEveningHour }
            if merged.quietHoursStart == nil { merged.quietHoursStart = currentQuietStart }
            if merged.quietHoursEnd == nil { merged.quietHoursEnd = currentQuietEnd }

            // Preserve all other local values if server returned nil
            if merged.notificationsEnabled == nil { merged.notificationsEnabled = currentPrefs.notificationsEnabled }
            if merged.morningBriefingEnabled == nil { merged.morningBriefingEnabled = currentPrefs.morningBriefingEnabled }
            if merged.eveningSummaryEnabled == nil { merged.eveningSummaryEnabled = currentPrefs.eveningSummaryEnabled }
            if merged.eventRemindersEnabled == nil { merged.eventRemindersEnabled = currentPrefs.eventRemindersEnabled }
            if merged.clashAlertsEnabled == nil { merged.clashAlertsEnabled = currentPrefs.clashAlertsEnabled }
            if merged.taskRemindersEnabled == nil { merged.taskRemindersEnabled = currentPrefs.taskRemindersEnabled }
            if merged.proactiveNudgesEnabled == nil { merged.proactiveNudgesEnabled = currentPrefs.proactiveNudgesEnabled }
            if merged.lunchRemindersEnabled == nil { merged.lunchRemindersEnabled = currentPrefs.lunchRemindersEnabled }
            if merged.eventReminderMinutes == nil { merged.eventReminderMinutes = currentPrefs.eventReminderMinutes }
            if merged.quietHoursEnabled == nil { merged.quietHoursEnabled = currentPrefs.quietHoursEnabled }
            if merged.maxNudgesPerDay == nil { merged.maxNudgesPerDay = currentPrefs.maxNudgesPerDay }
            if merged.minMinutesBetweenNotifications == nil { merged.minMinutesBetweenNotifications = currentPrefs.minMinutesBetweenNotifications }
            if merged.weekendReduced == nil { merged.weekendReduced = currentPrefs.weekendReduced }

            preferences = merged
            cachePreferences(merged)
            lastSyncedAt = Date()
            print("🔔 NotificationPreferencesService: Saved preferences to backend successfully")
        } catch {
            self.error = error.localizedDescription
            print("🔔 NotificationPreferencesService: Failed to save - \(error.localizedDescription)")
            // On failure, keep local changes - don't revert
        }

        isSaving = false
    }

    /// Debounced save - waits 500ms before saving to batch rapid changes
    func debouncedSave() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
            if !Task.isCancelled {
                await savePreferences()
            }
        }
    }

    // MARK: - Preference Updates

    /// Update master notifications switch
    func setNotificationsEnabled(_ enabled: Bool) {
        preferences.notificationsEnabled = enabled
        debouncedSave()

        // Also update local notification scheduling services
        if !enabled {
            // Disable all local notification services when master switch is off
            MorningBriefingNotificationService.shared.isEnabled = false
            EveningSummaryNotificationService.shared.isEnabled = false
        }
    }

    /// Update morning briefing settings
    func setMorningBriefing(enabled: Bool, hour: Int? = nil) {
        preferences.morningBriefingEnabled = enabled
        if let hour = hour {
            preferences.morningBriefingHour = hour
        }
        debouncedSave()

        // Sync with local notification service
        MorningBriefingNotificationService.shared.isEnabled = enabled && (preferences.notificationsEnabled ?? true)
    }

    /// Update evening summary settings
    func setEveningSummary(enabled: Bool, hour: Int? = nil) {
        preferences.eveningSummaryEnabled = enabled
        if let hour = hour {
            preferences.eveningSummaryHour = hour
        }
        debouncedSave()

        // Sync with local notification service
        EveningSummaryNotificationService.shared.isEnabled = enabled && (preferences.notificationsEnabled ?? true)
    }

    /// Update event reminders setting
    func setEventReminders(enabled: Bool, minutesBefore: Int? = nil) {
        preferences.eventRemindersEnabled = enabled
        if let minutes = minutesBefore {
            preferences.eventReminderMinutes = minutes
        }
        debouncedSave()
    }

    /// Update clash alerts setting
    func setClashAlerts(enabled: Bool) {
        preferences.clashAlertsEnabled = enabled
        debouncedSave()
    }

    /// Update task reminders setting
    func setTaskReminders(enabled: Bool) {
        preferences.taskRemindersEnabled = enabled
        debouncedSave()
    }

    /// Update proactive nudges setting
    func setProactiveNudges(enabled: Bool, maxPerDay: Int? = nil) {
        preferences.proactiveNudgesEnabled = enabled
        if let max = maxPerDay {
            preferences.maxNudgesPerDay = max
        }
        debouncedSave()
    }

    /// Update lunch reminders setting
    func setLunchReminders(enabled: Bool) {
        preferences.lunchRemindersEnabled = enabled
        debouncedSave()
    }

    /// Update quiet hours settings
    func setQuietHours(enabled: Bool, start: String? = nil, end: String? = nil) {
        preferences.quietHoursEnabled = enabled
        if let start = start {
            preferences.quietHoursStart = start
        }
        if let end = end {
            preferences.quietHoursEnd = end
        }
        debouncedSave()
    }

    /// Update weekend reduced setting
    func setWeekendReduced(_ reduced: Bool) {
        preferences.weekendReduced = reduced
        debouncedSave()
    }

    /// Update rate limiting settings
    func setRateLimits(maxNudges: Int? = nil, minMinutesBetween: Int? = nil) {
        if let max = maxNudges {
            preferences.maxNudgesPerDay = max
        }
        if let min = minMinutesBetween {
            preferences.minMinutesBetweenNotifications = min
        }
        debouncedSave()
    }

    // MARK: - Quiet Hours Check

    /// Check if currently in quiet hours
    func checkQuietHoursStatus() async {
        do {
            let status = try await apiService.getQuietHoursStatus()
            isQuietHoursActive = status.isQuietHours
        } catch {
            print("🔔 NotificationPreferencesService: Failed to check quiet hours - \(error.localizedDescription)")
        }
    }

    // MARK: - Test Notifications

    /// Check if device token is available
    var hasDeviceToken: Bool {
        let token = UserDefaults.standard.string(forKey: "device_token")
        return token != nil && !token!.isEmpty
    }

    /// Get device token status for debugging
    var deviceTokenStatus: String {
        if let token = UserDefaults.standard.string(forKey: "device_token"), !token.isEmpty {
            return "Registered (\(token.prefix(8))...)"
        }
        #if targetEnvironment(simulator)
        return "Not available (Simulator)"
        #else
        return "Not registered"
        #endif
    }

    /// Send a test notification of specified type
    func sendTestNotification(type: String) async -> (success: Bool, message: String) {
        // Check if running on simulator
        #if targetEnvironment(simulator)
        return (false, "Push notifications don't work on the iOS Simulator. Please test on a physical device.")
        #endif

        // Check if device token exists locally first
        let deviceToken = UserDefaults.standard.string(forKey: "device_token")
        print("🔔 NotificationPreferencesService: Device token check - exists: \(deviceToken != nil), value: \(deviceToken?.prefix(16) ?? "nil")")

        if deviceToken == nil || deviceToken?.isEmpty == true {
            return (false, "No device token registered. Go to Settings > Notifications and make sure notifications are enabled, then restart the app.")
        }

        do {
            let response = try await apiService.sendTestNotificationWithType(type)
            if let reason = response.reason {
                // Provide user-friendly messages for common errors
                let friendlyMessage: String
                switch reason.lowercased() {
                case let r where r.contains("device token") || r.contains("not registered"):
                    friendlyMessage = "Device token not registered on server. Try restarting the app to re-register."
                case let r where r.contains("not configured") || r.contains("service unavailable"):
                    friendlyMessage = "Push notification service is being configured. Please try again later."
                case let r where r.contains("quiet hours"):
                    friendlyMessage = "Blocked by quiet hours. Disable quiet hours or wait until they end."
                case let r where r.contains("rate limit"):
                    friendlyMessage = "Too many notifications sent recently. Please wait a few minutes."
                case let r where r.contains("disabled"):
                    friendlyMessage = "This notification type is disabled in your preferences."
                case let r where r.contains("apns") || r.contains("delivery"):
                    friendlyMessage = "Delivery failed. Check that notifications are enabled in iOS Settings > Clara."
                default:
                    friendlyMessage = reason
                }
                return (false, friendlyMessage)
            }
            return (true, response.message)
        } catch let error as NSError {
            print("🔔 NotificationPreferencesService: Test notification error - code: \(error.code), message: \(error.localizedDescription)")

            // Handle specific HTTP status codes
            if error.code == 503 {
                return (false, "Push notification service is being configured. Please try again later.")
            } else if error.code == 500 {
                return (false, "Server error while sending notification. Please try again.")
            }

            let errorMessage = error.localizedDescription
            if errorMessage.contains("device") || errorMessage.contains("token") {
                return (false, "Push notifications not set up. Enable notifications in Settings and restart the app.")
            }
            return (false, errorMessage)
        }
    }

    // MARK: - Caching

    private func cachePreferences(_ prefs: NotificationPreferences) {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: "cached_notification_preferences")
            UserDefaults.standard.set(Date(), forKey: "notification_preferences_cached_at")
        }
    }

    private func loadCachedPreferences() {
        if let data = UserDefaults.standard.data(forKey: "cached_notification_preferences"),
           let cached = try? JSONDecoder().decode(NotificationPreferences.self, from: data) {
            preferences = cached
            lastSyncedAt = UserDefaults.standard.object(forKey: "notification_preferences_cached_at") as? Date
            print("🔔 NotificationPreferencesService: Loaded cached preferences")
        }
    }

    // MARK: - Initialization on App Launch

    /// Call this when app launches to sync preferences
    func initialize() {
        Task {
            await syncPreferences()
            await checkQuietHoursStatus()
        }
    }
}

// MARK: - Notification Engagement Tracker

/// Tracks user engagement with notifications
@MainActor
class NotificationEngagementTracker: ObservableObject {
    static let shared = NotificationEngagementTracker()

    private let apiService = APIService()

    private init() {}

    /// Track that a notification was opened (displayed)
    func trackOpened(notificationId: Int64) {
        Task {
            do {
                try await apiService.markNotificationOpened(notificationId: notificationId)
                print("🔔 EngagementTracker: Marked notification \(notificationId) as opened")
            } catch {
                print("🔔 EngagementTracker: Failed to track opened - \(error.localizedDescription)")
            }
        }
    }

    /// Track that a notification was clicked/tapped
    func trackClicked(notificationId: Int64) {
        Task {
            do {
                try await apiService.markNotificationClicked(notificationId: notificationId)
                print("🔔 EngagementTracker: Marked notification \(notificationId) as clicked")
            } catch {
                print("🔔 EngagementTracker: Failed to track clicked - \(error.localizedDescription)")
            }
        }
    }

    /// Track that a user acted on a notification (e.g., completed a task)
    func trackActed(notificationId: Int64) {
        Task {
            do {
                try await apiService.markNotificationActed(notificationId: notificationId)
                print("🔔 EngagementTracker: Marked notification \(notificationId) as acted")
            } catch {
                print("🔔 EngagementTracker: Failed to track acted - \(error.localizedDescription)")
            }
        }
    }

    /// Track that a notification was dismissed
    func trackDismissed(notificationId: Int64) {
        Task {
            do {
                try await apiService.markNotificationDismissed(notificationId: notificationId)
                print("🔔 EngagementTracker: Marked notification \(notificationId) as dismissed")
            } catch {
                print("🔔 EngagementTracker: Failed to track dismissed - \(error.localizedDescription)")
            }
        }
    }
}
