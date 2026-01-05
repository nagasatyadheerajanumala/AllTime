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
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        let type = userInfo["type"] as? String
        let destination = userInfo["destination"] as? String

        diagnostics.logDeepLinkReceived(url: nil, type: type, destination: destination)
        os_log("[DEEPLINK] Notification tapped: type=%{public}@, destination=%{public}@",
               log: log, type: .info, type ?? "nil", destination ?? "nil")

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
}
