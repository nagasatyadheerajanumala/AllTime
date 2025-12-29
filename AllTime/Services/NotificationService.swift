import Foundation
import UserNotifications
import Combine

class NotificationService: NSObject, ObservableObject {
    static let shared = NotificationService()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isDailySummaryEnabled = true
    @Published var isEventRemindersEnabled = true
    @Published var dailySummaryTime = Date()
    
    private override init() {
        super.init()
        checkAuthorizationStatus()
        loadSettings()
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
            }
            
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.authorizationStatus = settings.authorizationStatus
            }
        }
    }
    
    func scheduleDailySummaryNotification() {
        guard isDailySummaryEnabled && authorizationStatus == .authorized else { return }
        
        // Remove existing daily summary notifications
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily-summary"])
        
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Summary is Ready"
        content.body = "Check out your AI-generated calendar insights for today"
        content.sound = .default
        content.badge = 1
        
        // Schedule for the selected time
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: dailySummaryTime)
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: "daily-summary",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily summary notification: \(error)")
            }
        }
    }
    
    func scheduleEventReminder(for event: Event, minutesBefore: Int = 15) {
        guard isEventRemindersEnabled && authorizationStatus == .authorized else { return }
        guard let startDate = event.startDate else { return }
        
        let reminderDate = startDate.addingTimeInterval(-TimeInterval(minutesBefore * 60))
        
        // Don't schedule if the reminder time has passed
        guard reminderDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event"
        content.body = "\(event.title) starts in \(minutesBefore) minutes"
        content.sound = .default
        
        if let location = event.location {
            content.userInfo = ["location": location]
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderDate.timeIntervalSinceNow,
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: "event-reminder-\(event.id)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling event reminder: \(error)")
            }
        }
    }
    
    func cancelEventReminder(for eventId: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["event-reminder-\(eventId)"])
    }
    
    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "AllTime Test"
        content.body = "Your notification settings are working correctly!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "test-notification",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error)")
            }
        }
    }
    
    private func loadSettings() {
        isDailySummaryEnabled = UserDefaults.standard.bool(forKey: "daily_summary_enabled")
        isEventRemindersEnabled = UserDefaults.standard.bool(forKey: "event_reminders_enabled")
        
        if let timeData = UserDefaults.standard.data(forKey: "daily_summary_time"),
           let time = try? JSONDecoder().decode(Date.self, from: timeData) {
            dailySummaryTime = time
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(isDailySummaryEnabled, forKey: "daily_summary_enabled")
        UserDefaults.standard.set(isEventRemindersEnabled, forKey: "event_reminders_enabled")
        
        if let timeData = try? JSONEncoder().encode(dailySummaryTime) {
            UserDefaults.standard.set(timeData, forKey: "daily_summary_time")
        }
        
        scheduleDailySummaryNotification()
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo

        // Check destination from userInfo first (preferred)
        if let destination = userInfo["destination"] as? String {
            switch destination {
            case "day-review":
                NotificationCenter.default.post(name: .navigateToDayReview, object: nil)
                completionHandler()
                return
            case "summary":
                NotificationCenter.default.post(name: .navigateToEveningSummary, object: nil)
                completionHandler()
                return
            default:
                break
            }
        }

        // Check notification type from userInfo
        if let notificationType = userInfo["type"] as? String {
            switch notificationType {
            case "evening_summary":
                // Check for day-review destination, fallback to evening summary
                if let dest = userInfo["destination"] as? String, dest == "day-review" {
                    NotificationCenter.default.post(name: .navigateToDayReview, object: nil)
                } else {
                    NotificationCenter.default.post(name: .navigateToEveningSummary, object: nil)
                }
            case "morning_briefing":
                NotificationCenter.default.post(name: .navigateToToday, object: nil)
            default:
                break
            }
        }

        // Fallback to identifier-based navigation
        if identifier == "daily-summary" {
            NotificationCenter.default.post(name: .navigateToSummary, object: nil)
        } else if identifier == "evening-summary" || identifier == "evening-summary-test" {
            NotificationCenter.default.post(name: .navigateToEveningSummary, object: nil)
        } else if identifier == "morning-briefing" || identifier == "morning-briefing-test" {
            NotificationCenter.default.post(name: .navigateToToday, object: nil)
        } else if identifier.hasPrefix("event-reminder-") {
            NotificationCenter.default.post(name: .navigateToCalendar, object: nil)
        }

        completionHandler()
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let navigateToSummary = Notification.Name("navigateToSummary")
    static let navigateToCalendar = Notification.Name("navigateToCalendar")
    static let navigateToEveningSummary = Notification.Name("navigateToEveningSummary")
    static let navigateToToday = Notification.Name("navigateToToday")
    static let navigateToDayReview = Notification.Name("navigateToDayReview")
}

