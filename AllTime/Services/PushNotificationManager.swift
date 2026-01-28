import Foundation
import UserNotifications
import Combine
import os.log

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    @Published var isRegistered = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    private let diagnostics = AuthDiagnostics.shared
    private let log = OSLog(subsystem: "com.alltime.clara", category: "DEEPLINK")

    static let shared = PushNotificationManager()

    override init() {
        super.init()
        checkRegistrationStatus()
    }
    
    // MARK: - Registration Status
    
    private func checkRegistrationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isRegistered = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Request Permission

    func registerForPushNotifications() {
        print("🔔 PushNotificationManager: Requesting push notification permission...")
        isLoading = true
        errorMessage = nil

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("🔔 PushNotificationManager: Permission request failed: \(error.localizedDescription)")
                    return
                }

                if granted {
                    print("🔔 PushNotificationManager: Permission granted, registering device token...")
                    self.registerDeviceToken()
                } else {
                    print("🔔 PushNotificationManager: Permission denied")
                    self.errorMessage = "Push notifications are disabled. Please enable them in Settings."
                }
            }
        }
    }
    
    // MARK: - Device Token Registration

    private func registerDeviceToken() {
        guard let deviceToken = getDeviceToken() else {
            print("🔔 PushNotificationManager: No device token available")
            errorMessage = "Unable to get device token. Please try again."
            return
        }

        print("🔔 PushNotificationManager: Registering device token with backend...")
        isLoading = true

        Task {
            do {
                try await apiService.registerDeviceToken(deviceToken)
                isRegistered = true
                isLoading = false
                print("🔔 PushNotificationManager: Device token registered successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("🔔 PushNotificationManager: Failed to register device token: \(error.localizedDescription)")
            }
        }
    }

    private func getDeviceToken() -> String? {
        // In a real implementation, this would get the actual device token from APNs
        // For now, we'll use a placeholder or stored token
        return UserDefaults.standard.string(forKey: "device_token")
    }
    
    // MARK: - Test Notification
    
    func sendTestNotification() {
        print("🔔 PushNotificationManager: Sending test notification...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await apiService.sendTestNotification()
                isLoading = false
                print("🔔 PushNotificationManager: Test notification sent successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("🔔 PushNotificationManager: Failed to send test notification: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Local Notifications
    
    func scheduleLocalNotification(title: String, body: String, timeInterval: TimeInterval = 1.0) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("🔔 PushNotificationManager: Failed to schedule local notification: \(error.localizedDescription)")
            } else {
                print("🔔 PushNotificationManager: Local notification scheduled successfully")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension PushNotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Track that notification was displayed
        let userInfo = notification.request.content.userInfo
        trackNotificationDisplayed(userInfo: userInfo)

        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String
        let destination = userInfo["destination"] as? String
        let title = response.notification.request.content.title
        let body = response.notification.request.content.body

        diagnostics.logDeepLinkReceived(url: nil, type: type, destination: destination)
        os_log("[DEEPLINK] Notification tapped: type=%{public}@, destination=%{public}@",
               log: log, type: .info, type ?? "nil", destination ?? "nil")

        // Track engagement with backend
        if let notificationId = extractNotificationId(from: userInfo) {
            trackNotificationEngagement(notificationId: notificationId, action: response.actionIdentifier)
        }

        // Save notification to history
        saveNotificationToHistory(type: type, title: title, body: body, userInfo: userInfo)

        // Handle morning briefing notifications
        if type == "morning_briefing" {
            os_log("[DEEPLINK] Morning briefing notification - navigating to Today", log: log, type: .info)
            Task { @MainActor in
                await handleAuthenticatedNavigation(destination: "today") {
                    NavigationManager.shared.navigateToToday()
                }
            }
            completionHandler()
            return
        }

        // Handle evening summary notifications
        if type == "evening_summary" {
            os_log("[DEEPLINK] Evening summary notification - navigating to Day Review", log: log, type: .info)
            Task { @MainActor in
                await handleAuthenticatedNavigation(destination: "day-review") {
                    NavigationManager.shared.navigateToDayReview()
                }
            }
            completionHandler()
            return
        }

        // Handle proactive nudge notifications
        if type == "nudge" {
            let nudgeType = userInfo["nudge_type"] as? String ?? "unknown"
            let actionUrl = userInfo["action_url"] as? String
            os_log("[DEEPLINK] Nudge notification tapped - type: %{public}@", log: log, type: .info, nudgeType)

            Task { @MainActor in
                // Track nudge engagement
                print("📱 Nudge opened: \(nudgeType)")

                await handleAuthenticatedNavigation(destination: actionUrl ?? destination ?? "today") {
                    if let actionUrl = actionUrl {
                        NavigationManager.shared.handleDestination(actionUrl)
                    } else if let destination = destination {
                        NavigationManager.shared.handleDestination(destination)
                    } else {
                        NavigationManager.shared.navigateToToday()
                    }
                }
            }
            completionHandler()
            return
        }

        // Handle reminder notifications
        if let reminderId = userInfo["reminder_id"] as? Int64, type == "reminder" {
            os_log("[DEEPLINK] Reminder notification tapped - ID: %{public}lld", log: log, type: .info, reminderId)
            handleReminderNotification(reminderId: reminderId, actionIdentifier: response.actionIdentifier)
            completionHandler()
            return
        }

        // Handle generic destination-based navigation
        if let destination = destination {
            os_log("[DEEPLINK] Generic notification with destination: %{public}@", log: log, type: .info, destination)
            Task { @MainActor in
                await handleAuthenticatedNavigation(destination: destination) {
                    NavigationManager.shared.handleDestination(destination)
                }
            }
        }

        completionHandler()
    }

    /// Handle navigation that requires authentication, waiting for session restoration if needed
    private func handleAuthenticatedNavigation(destination: String, action: @escaping () -> Void) async {
        // If session is being restored, wait for it to complete
        if diagnostics.shouldWaitForSessionRestoration {
            os_log("[DEEPLINK] Session restoring, waiting before navigation to %{public}@", log: log, type: .info, destination)
            diagnostics.logDeepLinkPending(destination: destination, reason: "Session restoring")

            // Wait up to 5 seconds for session restoration
            for _ in 0..<50 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                if !diagnostics.shouldWaitForSessionRestoration {
                    break
                }
            }

            os_log("[DEEPLINK] Session restoration complete, isLoggedIn=%{public}@",
                   log: log, type: .info, diagnostics.isLoggedIn ? "true" : "false")
        }

        // Now check if user is authenticated
        if diagnostics.isLoggedIn || KeychainManager.shared.hasValidTokens() {
            os_log("[DEEPLINK] User authenticated, navigating to %{public}@", log: log, type: .info, destination)
            diagnostics.logDeepLinkProcessed(destination: destination)
            action()
        } else {
            // Store pending destination for after sign-in
            os_log("[DEEPLINK] User not authenticated, storing pending destination: %{public}@", log: log, type: .info, destination)
            diagnostics.logDeepLinkPending(destination: destination, reason: "Not authenticated")
            NavigationManager.shared.setPendingDestination(destination)
        }
    }
    
    // MARK: - Reminder Notification Handling
    
    private func handleReminderNotification(reminderId: Int64, actionIdentifier: String) {
        Task { @MainActor in
            let apiService = APIService()
            
            switch actionIdentifier {
            case UNNotificationDefaultActionIdentifier:
                // User tapped the notification (not an action button)
                print("🔔 PushNotificationManager: Opening reminder detail for ID: \(reminderId)")
                // Post notification to navigate to reminder detail
                NotificationCenter.default.post(
                    name: NSNotification.Name("OpenReminder"),
                    object: nil,
                    userInfo: ["reminderId": reminderId]
                )
                
            case "COMPLETE_ACTION":
                // User tapped "Complete" action
                print("🔔 PushNotificationManager: Completing reminder ID: \(reminderId)")
                do {
                    _ = try await apiService.completeReminder(id: reminderId)
                    print("✅ PushNotificationManager: Reminder completed successfully")
                } catch {
                    print("❌ PushNotificationManager: Failed to complete reminder: \(error.localizedDescription)")
                }
                
            case "SNOOZE_ACTION":
                // User tapped "Snooze" action
                print("🔔 PushNotificationManager: Snoozing reminder ID: \(reminderId)")
                let snoozeDate = Date().addingTimeInterval(30 * 60) // 30 minutes
                do {
                    _ = try await apiService.snoozeReminder(id: reminderId, until: snoozeDate)
                    print("✅ PushNotificationManager: Reminder snoozed successfully")
                } catch {
                    print("❌ PushNotificationManager: Failed to snooze reminder: \(error.localizedDescription)")
                }
                
            default:
                print("🔔 PushNotificationManager: Unknown action: \(actionIdentifier)")
            }
        }
    }

    // MARK: - Notification History

    /// Save received notification to history for display in the app
    private func saveNotificationToHistory(type: String?, title: String, body: String, userInfo: [AnyHashable: Any]) {
        guard let typeString = type,
              let notificationType = NotificationHistoryItem.NotificationType(rawValue: typeString) else {
            print("🔔 PushNotificationManager: Unknown notification type '\(type ?? "nil")' - not saving to history")
            return
        }

        // Build notification data based on type
        var data = NotificationData(destination: userInfo["destination"] as? String)

        switch notificationType {
        case .morningBriefing:
            data.meetingsCount = userInfo["meetings_count"] as? Int
            data.focusTimeAvailable = userInfo["focus_time"] as? String

        case .eveningSummary:
            data.meetingsCompleted = userInfo["meetings_completed"] as? Int
            data.totalMeetings = userInfo["total_meetings"] as? Int
            data.completionPercentage = userInfo["completion_percentage"] as? Int

        case .eventReminder:
            data.eventId = userInfo["event_id"] as? String
            data.eventTitle = userInfo["event_title"] as? String
            data.eventTime = userInfo["event_time"] as? String

        case .reminder, .reminderDue:
            if let reminderId = userInfo["reminder_id"] as? Int64 {
                data.reminderId = reminderId
            }

        case .nudge:
            data.nudgeType = userInfo["nudge_type"] as? String
            data.actionUrl = userInfo["action_url"] as? String

        case .calendarSync, .dailySummary, .test, .system:
            break
        }

        let historyItem = NotificationHistoryItem(
            type: notificationType,
            title: title,
            body: body,
            data: data
        )

        NotificationHistoryService.shared.addNotification(historyItem)
        print("🔔 PushNotificationManager: Saved \(typeString) notification to history")
    }

    // MARK: - Engagement Tracking

    /// Extract notification ID from push payload
    private func extractNotificationId(from userInfo: [AnyHashable: Any]) -> Int64? {
        // The backend sends notification_id or history_id in the payload
        if let notificationId = userInfo["notification_id"] as? Int64 {
            return notificationId
        }
        if let notificationId = userInfo["notification_id"] as? Int {
            return Int64(notificationId)
        }
        if let notificationId = userInfo["history_id"] as? Int64 {
            return notificationId
        }
        if let notificationId = userInfo["history_id"] as? Int {
            return Int64(notificationId)
        }
        // Try string conversion
        if let notificationIdString = userInfo["notification_id"] as? String,
           let notificationId = Int64(notificationIdString) {
            return notificationId
        }
        if let notificationIdString = userInfo["history_id"] as? String,
           let notificationId = Int64(notificationIdString) {
            return notificationId
        }
        return nil
    }

    /// Track notification engagement with backend
    private func trackNotificationEngagement(notificationId: Int64, action: String) {
        let tracker = NotificationEngagementTracker.shared

        switch action {
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            tracker.trackClicked(notificationId: notificationId)
            print("🔔 PushNotificationManager: Tracked click for notification \(notificationId)")

        case UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            tracker.trackDismissed(notificationId: notificationId)
            print("🔔 PushNotificationManager: Tracked dismiss for notification \(notificationId)")

        case "COMPLETE_ACTION", "DONE_ACTION":
            // User took action on the notification
            tracker.trackActed(notificationId: notificationId)
            print("🔔 PushNotificationManager: Tracked action for notification \(notificationId)")

        default:
            // Custom action - also count as acted
            if action.hasSuffix("_ACTION") {
                tracker.trackActed(notificationId: notificationId)
                print("🔔 PushNotificationManager: Tracked custom action '\(action)' for notification \(notificationId)")
            } else {
                // Default to clicked for unknown actions
                tracker.trackClicked(notificationId: notificationId)
            }
        }
    }

    /// Track that a notification was displayed (for foreground notifications)
    func trackNotificationDisplayed(userInfo: [AnyHashable: Any]) {
        if let notificationId = extractNotificationId(from: userInfo) {
            NotificationEngagementTracker.shared.trackOpened(notificationId: notificationId)
            print("🔔 PushNotificationManager: Tracked display for notification \(notificationId)")
        }
    }
}
