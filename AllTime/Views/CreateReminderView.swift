import SwiftUI

struct CreateReminderView: View {
    @ObservedObject var viewModel: ReminderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var reminderMinutesBefore: Int? = 15
    @State private var selectedPriority: ReminderPriority? = nil
    @State private var recurrenceRule: String? = nil
    @State private var notificationEnabled = true
    @State private var notificationSound: NotificationSound = .default
    @State private var eventId: Int64? = nil
    @State private var syncToEventKit = true
    
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    @ObservedObject private var eventKitManager = EventKitReminderManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Date & Time") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Reminder Before", selection: $reminderMinutesBefore) {
                        Text("None").tag(nil as Int?)
                        Text("5 minutes").tag(5 as Int?)
                        Text("15 minutes").tag(15 as Int?)
                        Text("30 minutes").tag(30 as Int?)
                        Text("1 hour").tag(60 as Int?)
                        Text("2 hours").tag(120 as Int?)
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
                
                Section("Recurrence") {
                    Picker("Repeat", selection: $recurrenceRule) {
                        Text("Never").tag(nil as String?)
                        Text("Daily").tag("daily" as String?)
                        Text("Weekly").tag("weekly" as String?)
                        Text("Monthly").tag("monthly" as String?)
                        Text("Yearly").tag("yearly" as String?)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationEnabled)
                    
                    if notificationEnabled {
                        Picker("Sound", selection: $notificationSound) {
                            ForEach(NotificationSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                    }
                }
                
                Section("Sync") {
                    Toggle("Sync to iOS Reminders", isOn: $syncToEventKit)
                    
                    if !eventKitManager.isAuthorized && syncToEventKit {
                        Button("Enable Reminder Access") {
                            Task {
                                _ = await eventKitManager.requestAuthorization()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Reminder")
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
                    .disabled(title.isEmpty || isCreating)
                }
            }
        }
    }
    
    private func createReminder() {
        guard !title.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        let request = ReminderRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: dueDate,
            reminderTime: nil,
            reminderMinutesBefore: reminderMinutesBefore,
            priority: selectedPriority,
            eventId: eventId,
            recurrenceRule: recurrenceRule,
            notificationEnabled: notificationEnabled,
            notificationSound: notificationSound.rawValue
        )
        
        Task {
            do {
                _ = try await viewModel.createReminder(request, syncToEventKit: syncToEventKit)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}

// MARK: - Edit Reminder View

struct EditReminderView: View {
    let reminder: Reminder
    @ObservedObject var viewModel: ReminderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var reminderMinutesBefore: Int?
    @State private var selectedPriority: ReminderPriority?
    @State private var recurrenceRule: String?
    @State private var notificationEnabled: Bool
    @State private var notificationSound: NotificationSound
    
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    init(reminder: Reminder, viewModel: ReminderViewModel) {
        self.reminder = reminder
        self.viewModel = viewModel
        _title = State(initialValue: reminder.title)
        _description = State(initialValue: reminder.description ?? "")
        _dueDate = State(initialValue: reminder.dueDate)
        _reminderMinutesBefore = State(initialValue: nil) // Calculate from reminderTime if needed
        _selectedPriority = State(initialValue: reminder.priority)
        _recurrenceRule = State(initialValue: reminder.recurrenceRule)
        _notificationEnabled = State(initialValue: reminder.notificationEnabled)
        _notificationSound = State(initialValue: NotificationSound(rawValue: reminder.notificationSound ?? "default") ?? .default)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Date & Time") {
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Reminder Before", selection: $reminderMinutesBefore) {
                        Text("Keep current").tag(nil as Int?)
                        Text("5 minutes").tag(5 as Int?)
                        Text("15 minutes").tag(15 as Int?)
                        Text("30 minutes").tag(30 as Int?)
                        Text("1 hour").tag(60 as Int?)
                        Text("2 hours").tag(120 as Int?)
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
                
                Section("Recurrence") {
                    Picker("Repeat", selection: $recurrenceRule) {
                        Text("Never").tag(nil as String?)
                        Text("Daily").tag("daily" as String?)
                        Text("Weekly").tag("weekly" as String?)
                        Text("Monthly").tag("monthly" as String?)
                        Text("Yearly").tag("yearly" as String?)
                    }
                }
                
                Section("Notifications") {
                    Toggle("Enable Notifications", isOn: $notificationEnabled)
                    
                    if notificationEnabled {
                        Picker("Sound", selection: $notificationSound) {
                            ForEach(NotificationSound.allCases, id: \.self) { sound in
                                Text(sound.displayName).tag(sound)
                            }
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateReminder()
                    }
                    .disabled(title.isEmpty || isUpdating)
                }
            }
        }
    }
    
    private func updateReminder() {
        guard !title.isEmpty else { return }
        
        isUpdating = true
        errorMessage = nil
        
        let request = ReminderRequest(
            title: title,
            description: description.isEmpty ? nil : description,
            dueDate: dueDate,
            reminderTime: nil,
            reminderMinutesBefore: reminderMinutesBefore,
            priority: selectedPriority,
            eventId: reminder.eventId,
            recurrenceRule: recurrenceRule,
            notificationEnabled: notificationEnabled,
            notificationSound: notificationSound.rawValue
        )
        
        Task {
            do {
                _ = try await viewModel.updateReminder(id: reminder.id, request: request)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isUpdating = false
        }
    }
}

#Preview {
    CreateReminderView(viewModel: ReminderViewModel())
}

