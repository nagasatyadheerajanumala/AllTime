import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @ObservedObject private var morningBriefingService = MorningBriefingNotificationService.shared
    @AppStorage("daily_summary_enabled") private var dailySummaryEnabled = true
    @AppStorage("event_reminders_enabled") private var eventRemindersEnabled = true
    @State private var reminderTime: Date
    @State private var showingPermissionAlert = false

    // UserDefaults key for reminder time
    private static let reminderTimeKey = "daily_summary_time"

    init() {
        // Load saved reminder time or default to 8:00 PM
        if let savedTime = UserDefaults.standard.object(forKey: Self.reminderTimeKey) as? Date {
            _reminderTime = State(initialValue: savedTime)
        } else {
            var components = DateComponents()
            components.hour = 20
            components.minute = 0
            let defaultTime = Calendar.current.date(from: components) ?? Date()
            _reminderTime = State(initialValue: defaultTime)
        }
    }

    var body: some View {
        List {
            // MARK: - Morning Briefing Section
            Section {
                Toggle("Morning Briefing", isOn: $morningBriefingService.isEnabled)
                    .onChange(of: morningBriefingService.isEnabled) { _, enabled in
                        if enabled {
                            requestNotificationPermission()
                        }
                    }

                if morningBriefingService.isEnabled {
                    DatePicker(
                        "Delivery Time",
                        selection: $morningBriefingService.scheduledTime,
                        displayedComponents: .hourAndMinute
                    )
                }
            } header: {
                Text("Morning Briefing")
            } footer: {
                Text("Start your day with a preview of your schedule. Tap the notification to open your Today view.")
            }

            Section {
                Toggle("Daily Summary", isOn: $dailySummaryEnabled)
                .onChange(of: dailySummaryEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission()
                    }
                }

                if dailySummaryEnabled {
                    DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: reminderTime) { _, newTime in
                            UserDefaults.standard.set(newTime, forKey: Self.reminderTimeKey)
                        }
                }
            } header: {
                Text("Daily Briefings")
            } footer: {
                Text("Receive AI-generated daily summaries of your calendar")
            }
            
            Section {
                Toggle("Event Reminders", isOn: $eventRemindersEnabled)
                .onChange(of: eventRemindersEnabled) { _, enabled in
                    if enabled {
                        requestNotificationPermission()
                    }
                }
            } header: {
                Text("Event Notifications")
            } footer: {
                Text("Get notified about upcoming events and schedule changes")
            }
            
            Section {
                Button("Test Morning Briefing") {
                    morningBriefingService.sendTestNotification()
                }
                .disabled(!morningBriefingService.isEnabled)

                Button("Test General Notification") {
                    sendTestNotification()
                }
                .disabled(!dailySummaryEnabled && !eventRemindersEnabled)
            } header: {
                Text("Testing")
            } footer: {
                Text("Send a test notification to verify your settings")
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notification Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive daily summaries and reminders.")
        }
        .onAppear {
            checkNotificationStatus()
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                // Only disable if notifications are not authorized
                // Don't enable automatically - respect user's saved preference
                if settings.authorizationStatus != .authorized {
                    dailySummaryEnabled = false
                    eventRemindersEnabled = false
                }
            }
        }
    }
    
    private func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Chrona Test"
        content.body = "Your notification settings are working correctly!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending test notification: \(error)")
            }
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}
