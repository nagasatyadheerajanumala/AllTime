import Foundation
import UserNotifications
import Combine

@MainActor
class PushNotificationManager: NSObject, ObservableObject {
    @Published var isRegistered = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
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
        print("🔔 PushNotificationManager: Notification tapped: \(response.notification.request.identifier)")
        completionHandler()
    }
}
