import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @StateObject private var viewModel = NotificationPreferencesViewModel()
    @State private var selectedTestType = "morning_briefing"

    var body: some View {
        List {
            // MARK: - Master Switch
            Section {
                Toggle("Enable Notifications", isOn: Binding(
                    get: { viewModel.notificationsEnabled },
                    set: { newValue in
                        viewModel.notificationsEnabled = newValue
                        if newValue {
                            viewModel.requestNotificationPermission()
                        }
                    }
                ))
            } header: {
                Text("Notifications")
            } footer: {
                Text("Turn off to disable all notifications from Clara.")
            }

            if viewModel.notificationsEnabled {
                // MARK: - Daily Briefings
                Section {
                    Toggle("Morning Briefing", isOn: Binding(
                        get: { viewModel.morningBriefingEnabled },
                        set: { viewModel.morningBriefingEnabled = $0 }
                    ))

                    if viewModel.morningBriefingEnabled {
                        Picker("Delivery Hour", selection: Binding(
                            get: { viewModel.morningBriefingHour },
                            set: { viewModel.morningBriefingHour = $0 }
                        )) {
                            ForEach(5..<12, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                    }

                    Toggle("Evening Summary", isOn: Binding(
                        get: { viewModel.eveningSummaryEnabled },
                        set: { viewModel.eveningSummaryEnabled = $0 }
                    ))

                    if viewModel.eveningSummaryEnabled {
                        Picker("Delivery Hour", selection: Binding(
                            get: { viewModel.eveningSummaryHour },
                            set: { viewModel.eveningSummaryHour = $0 }
                        )) {
                            ForEach(17..<23, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        }
                    }
                } header: {
                    Text("Daily Briefings")
                } footer: {
                    Text("Start and end your day with personalized insights about your schedule.")
                }

                // MARK: - Event & Task Reminders
                Section {
                    Toggle("Event Reminders", isOn: Binding(
                        get: { viewModel.eventRemindersEnabled },
                        set: { viewModel.eventRemindersEnabled = $0 }
                    ))

                    if viewModel.eventRemindersEnabled {
                        Picker("Reminder Time", selection: Binding(
                            get: { viewModel.eventReminderMinutes },
                            set: { viewModel.eventReminderMinutes = $0 }
                        )) {
                            ForEach(viewModel.eventReminderOptions, id: \.1) { option in
                                Text(option.0).tag(option.1)
                            }
                        }
                    }

                    Toggle("Task Reminders", isOn: Binding(
                        get: { viewModel.taskRemindersEnabled },
                        set: { viewModel.taskRemindersEnabled = $0 }
                    ))

                    Toggle("Clash Alerts", isOn: Binding(
                        get: { viewModel.clashAlertsEnabled },
                        set: { viewModel.clashAlertsEnabled = $0 }
                    ))
                } header: {
                    Text("Reminders & Alerts")
                } footer: {
                    Text("Get notified about upcoming events, task deadlines, and scheduling conflicts.")
                }

                // MARK: - Proactive Features
                Section {
                    Toggle("Smart Nudges", isOn: Binding(
                        get: { viewModel.proactiveNudgesEnabled },
                        set: { viewModel.proactiveNudgesEnabled = $0 }
                    ))

                    if viewModel.proactiveNudgesEnabled {
                        Picker("Max per Day", selection: Binding(
                            get: { viewModel.maxNudgesPerDay },
                            set: { viewModel.maxNudgesPerDay = $0 }
                        )) {
                            ForEach(viewModel.nudgesPerDayOptions, id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                    }

                    Toggle("Lunch Break Reminders", isOn: Binding(
                        get: { viewModel.lunchRemindersEnabled },
                        set: { viewModel.lunchRemindersEnabled = $0 }
                    ))
                } header: {
                    Text("Proactive Features")
                } footer: {
                    Text("Receive helpful suggestions based on your calendar and habits. Smart nudges help you stay productive without overwhelming you.")
                }

                // MARK: - Quiet Hours
                Section {
                    Toggle("Quiet Hours", isOn: Binding(
                        get: { viewModel.quietHoursEnabled },
                        set: { viewModel.quietHoursEnabled = $0 }
                    ))

                    if viewModel.quietHoursEnabled {
                        DatePicker(
                            "Start",
                            selection: Binding(
                                get: { viewModel.quietHoursStartTime },
                                set: { viewModel.quietHoursStartTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        DatePicker(
                            "End",
                            selection: Binding(
                                get: { viewModel.quietHoursEndTime },
                                set: { viewModel.quietHoursEndTime = $0 }
                            ),
                            displayedComponents: .hourAndMinute
                        )

                        if viewModel.preferencesService.isQuietHoursActive {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.purple)
                                Text("Quiet hours active now")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Quiet Hours")
                } footer: {
                    Text("No notifications will be sent during quiet hours, except for urgent calendar alerts.")
                }

                // MARK: - Rate Limiting
                Section {
                    Picker("Min Time Between", selection: Binding(
                        get: { viewModel.minMinutesBetween },
                        set: { viewModel.minMinutesBetween = $0 }
                    )) {
                        ForEach(viewModel.minMinutesOptions, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }

                    Toggle("Reduce on Weekends", isOn: Binding(
                        get: { viewModel.weekendReduced },
                        set: { viewModel.weekendReduced = $0 }
                    ))
                } header: {
                    Text("Notification Frequency")
                } footer: {
                    Text("Control how often you receive notifications to avoid overload.")
                }

                // MARK: - Test Notifications
                Section {
                    // Device token status
                    HStack {
                        Text("Push Status")
                        Spacer()
                        Text(viewModel.preferencesService.deviceTokenStatus)
                            .foregroundColor(viewModel.preferencesService.hasDeviceToken ? .green : .orange)
                            .font(.caption)
                    }

                    Picker("Test Type", selection: $selectedTestType) {
                        Text("Morning Briefing").tag("morning_briefing")
                        Text("Evening Summary").tag("evening_summary")
                        Text("General").tag("test")
                    }
                    .pickerStyle(.menu)

                    Button {
                        viewModel.sendTestNotification(type: selectedTestType)
                    } label: {
                        HStack {
                            Text("Send Test Notification")
                            Spacer()
                            if viewModel.preferencesService.isSaving {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(viewModel.preferencesService.isSaving || !viewModel.preferencesService.hasDeviceToken)

                    // Manual re-register button if no token
                    if !viewModel.preferencesService.hasDeviceToken {
                        Button {
                            viewModel.requestPushRegistration()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Register for Push Notifications")
                            }
                        }
                    }
                } header: {
                    Text("Testing")
                } footer: {
                    if viewModel.preferencesService.hasDeviceToken {
                        Text("Send a test notification to verify your settings are working.")
                    } else {
                        Text("Push notifications require a physical device. Make sure notifications are enabled in iOS Settings > Clara > Notifications.")
                    }
                }

                // MARK: - Sync Status
                if let lastSynced = viewModel.preferencesService.lastSyncedAt {
                    Section {
                        HStack {
                            Text("Last synced")
                            Spacer()
                            Text(lastSynced, style: .relative)
                                .foregroundColor(.secondary)
                        }

                        if viewModel.preferencesService.isLoading {
                            HStack {
                                ProgressView()
                                Text("Syncing...")
                                    .foregroundColor(.secondary)
                            }
                        }
                    } header: {
                        Text("Sync Status")
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.onAppear()
        }
        .alert("Notification Permission Required", isPresented: $viewModel.showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable notifications in Settings to receive alerts and reminders from Clara.")
        }
        .alert("Test Notification", isPresented: $viewModel.showingTestResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let result = viewModel.testNotificationResult {
                Text(result.success ? result.message : "Failed: \(result.message)")
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
}


// MARK: - Notification Stats View

struct NotificationStatsView: View {
    @StateObject private var viewModel = NotificationPreferencesViewModel()
    @State private var selectedDays = 30

    var body: some View {
        List {
            Picker("Time Period", selection: $selectedDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
                Text("90 days").tag(90)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .onChange(of: selectedDays) { _, newValue in
                viewModel.loadNotificationStats(days: newValue)
            }

            if viewModel.isLoadingStats {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if let stats = viewModel.notificationStats {
                Section("Overview") {
                    StatRow(label: "Total Sent", value: "\(stats.totalSent)")
                    StatRow(label: "Opened", value: "\(stats.totalOpened)", subvalue: stats.overallOpenRate)
                    StatRow(label: "Clicked", value: "\(stats.totalClicked)", subvalue: stats.overallClickRate)
                    StatRow(label: "Actions Taken", value: "\(stats.totalActed)", subvalue: stats.overallActionRate)
                }

                if let byType = stats.byType, !byType.isEmpty {
                    Section("By Type") {
                        ForEach(Array(byType.keys.sorted()), id: \.self) { type in
                            if let typeStats = byType[type] {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(formatTypeName(type))
                                        .font(.headline)
                                    HStack {
                                        Text("\(typeStats.total) sent")
                                        Spacer()
                                        Text("Open: \(typeStats.openRate)")
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.subheadline)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            } else {
                Text("No stats available")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Engagement Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadNotificationStats(days: selectedDays)
        }
    }

    private func formatTypeName(_ type: String) -> String {
        type.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var subvalue: String? = nil

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            VStack(alignment: .trailing) {
                Text(value)
                    .fontWeight(.semibold)
                if let subvalue = subvalue {
                    Text(subvalue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        NotificationSettingsView()
    }
}
