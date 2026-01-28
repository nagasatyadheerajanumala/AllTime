import UIKit
import UserNotifications

/// AppDelegate to handle APNs device token registration
/// SwiftUI apps need this to receive the device token callback
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        print("🚀 AppDelegate: didFinishLaunchingWithOptions")

        // Request notification permissions and register for remote notifications
        requestNotificationPermissions()

        return true
    }

    /// Request notification permissions and register for remote notifications
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            print("🔔 AppDelegate: Notification permission granted: \(granted)")
            if let error = error {
                print("🔔 AppDelegate: Notification permission error: \(error.localizedDescription)")
            }

            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    print("🔔 AppDelegate: Registered for remote notifications")
                }
            }
        }
    }

    /// Called when APNs successfully registers the device and returns a device token
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Convert token to string
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("🔔 AppDelegate: Received device token: \(tokenString.prefix(20))...")

        // Save token locally for immediate use
        UserDefaults.standard.set(tokenString, forKey: "device_token")
        print("🔔 AppDelegate: Device token saved to UserDefaults")

        // Register token with backend
        Task {
            do {
                let apiService = APIService()
                try await apiService.registerDeviceToken(tokenString)
                print("🔔 AppDelegate: Device token registered with backend")
            } catch {
                print("🔔 AppDelegate: Failed to register device token with backend: \(error.localizedDescription)")
            }
        }
    }

    /// Called when APNs registration fails
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("🔔 AppDelegate: Failed to register for remote notifications: \(error.localizedDescription)")

        // On simulator, this will always fail - that's expected
        #if targetEnvironment(simulator)
        print("🔔 AppDelegate: Running on simulator - push notifications are not supported")
        #endif
    }
}
