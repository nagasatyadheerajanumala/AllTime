import SwiftUI

struct EventRemindersSection: View {
    let eventId: Int64
    let eventStartDate: Date
    @StateObject private var reminderViewModel = ReminderViewModel()
    @State private var reminders: [Reminder] = []
    @State private var isLoading = false
    @State private var showingCreateReminder = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminders".uppercased())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .tracking(0.5)
                
                Spacer()
                
                Button(action: { showingCreateReminder = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if reminders.isEmpty {
                Text("No reminders set")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(reminders) { reminder in
                    ReminderRowView(
                        reminder: reminder,
                        onComplete: {
                            Task {
                                do {
                                    _ = try await reminderViewModel.completeReminder(id: reminder.id)
                                    await loadReminders()
                                } catch {
                                    print("Error completing reminder: \(error)")
                                }
                            }
                        },
                        onSnooze: {
                            Task {
                                do {
                                    let snoozeDate = Date().addingTimeInterval(30 * 60)
                                    _ = try await reminderViewModel.snoozeReminder(id: reminder.id, until: snoozeDate)
                                    await loadReminders()
                                } catch {
                                    print("Error snoozing reminder: \(error)")
                                }
                            }
                        },
                        onDelete: {
                            Task {
                                do {
                                    try await reminderViewModel.deleteReminder(id: reminder.id)
                                    await loadReminders()
                                } catch {
                                    print("Error deleting reminder: \(error)")
                                }
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .onAppear {
            Task {
                await loadReminders()
            }
        }
        .sheet(isPresented: $showingCreateReminder) {
            CreateEventReminderView(
                eventId: eventId,
                eventStartDate: eventStartDate,
                viewModel: reminderViewModel,
                onReminderCreated: {
                    Task {
                        await loadReminders()
                    }
                }
            )
        }
    }
    
    private func loadReminders() async {
        isLoading = true
        do {
            reminders = try await reminderViewModel.getRemindersForEvent(eventId: eventId)
        } catch {
            print("Error loading reminders: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Create Event Reminder View

struct CreateEventReminderView: View {
    let eventId: Int64
    let eventStartDate: Date
    @ObservedObject var viewModel: ReminderViewModel
    let onReminderCreated: () -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var reminderMinutesBefore: Int = 15
    @State private var selectedPriority: ReminderPriority? = nil
    @State private var notificationEnabled = true
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Reminder Time") {
                    Picker("Remind me", selection: $reminderMinutesBefore) {
                        Text("5 minutes before").tag(5)
                        Text("15 minutes before").tag(15)
                        Text("30 minutes before").tag(30)
                        Text("1 hour before").tag(60)
                        Text("2 hours before").tag(120)
                    }
                }
                
                Section("Priority") {
                    Picker("Priority", selection: $selectedPriority) {
                        Text("None").tag(nil as ReminderPriority?)
                        ForEach(ReminderPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority as ReminderPriority?)
                        }
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationEnabled)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createReminder()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }
    
    private func createReminder() {
        isCreating = true
        errorMessage = nil
        
        let request = ReminderRequest(
            title: "Event Reminder",
            description: nil,
            dueDate: eventStartDate,
            reminderTime: nil,
            reminderMinutesBefore: reminderMinutesBefore,
            priority: selectedPriority,
            eventId: eventId,
            recurrenceRule: nil,
            notificationEnabled: notificationEnabled,
            notificationSound: "default"
        )
        
        Task {
            do {
                _ = try await viewModel.createReminder(request)
                onReminderCreated()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

#Preview {
    EventRemindersSection(
        eventId: 123,
        eventStartDate: Date().addingTimeInterval(3600)
    )
    .padding()
}

