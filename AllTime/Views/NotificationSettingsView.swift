import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var dailySummaryEnabled = true
    @State private var eventRemindersEnabled = true
    @State private var reminderTime = Date()
    @State private var showingPermissionAlert = false
    
    var body: some View {
        List {
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
                Button("Test Notification") {
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
                dailySummaryEnabled = settings.authorizationStatus == .authorized
                eventRemindersEnabled = settings.authorizationStatus == .authorized
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
