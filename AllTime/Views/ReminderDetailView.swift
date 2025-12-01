import SwiftUI

struct ReminderDetailView: View {
    let reminder: Reminder
    @ObservedObject var viewModel: ReminderViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var isCompleting = false
    @State private var isSnoozing = false
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    Text(reminder.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .strikethrough(reminder.isCompleted)
                    
                    // Description
                    if let description = reminder.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        DetailRow(
                            icon: "clock",
                            title: "Due Date",
                            value: Self.dateFormatter.string(from: reminder.dueDate)
                        )
                        
                        if let reminderTime = reminder.reminderTime {
                            DetailRow(
                                icon: "bell",
                                title: "Reminder Time",
                                value: Self.dateFormatter.string(from: reminderTime)
                            )
                        }
                        
                        if let priority = reminder.priority {
                            HStack {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundColor(.secondary)
                                Text("Priority")
                                    .foregroundColor(.secondary)
                                Spacer()
                                PriorityBadge(priority: priority)
                            }
                        }
                        
                        if reminder.recurrenceRule != nil {
                            DetailRow(
                                icon: "repeat",
                                title: "Recurrence",
                                value: formatRecurrence(reminder.recurrenceRule ?? "")
                            )
                        }
                        
                        DetailRow(
                            icon: "checkmark.circle",
                            title: "Status",
                            value: reminder.status.displayName
                        )
                        
                        if reminder.notificationEnabled {
                            DetailRow(
                                icon: "bell.fill",
                                title: "Notifications",
                                value: "Enabled"
                            )
                        }
                        
                        if let eventId = reminder.eventId {
                            DetailRow(
                                icon: "calendar",
                                title: "Linked Event",
                                value: "Event #\(eventId)"
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Actions
                    if !reminder.isCompleted {
                        VStack(spacing: 12) {
                            Button(action: completeReminder) {
                                HStack {
                                    if isCompleting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Complete")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isCompleting)
                            
                            Button(action: snoozeReminder) {
                                HStack {
                                    if isSnoozing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    } else {
                                        Image(systemName: "moon.zzz")
                                        Text("Snooze for 30 minutes")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            .disabled(isSnoozing)
                            
                            Button(action: { showingDeleteConfirmation = true }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .foregroundColor(.red)
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEdit = true
                    }
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditReminderView(reminder: reminder, viewModel: viewModel)
            }
            .alert("Delete Reminder", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        try? await viewModel.deleteReminder(id: reminder.id)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this reminder?")
            }
        }
    }
    
    private func completeReminder() {
        isCompleting = true
        Task {
            do {
                _ = try await viewModel.completeReminder(id: reminder.id)
                dismiss()
            } catch {
                print("Error completing reminder: \(error)")
            }
            isCompleting = false
        }
    }
    
    private func snoozeReminder() {
        isSnoozing = true
        Task {
            do {
                let snoozeDate = Date().addingTimeInterval(30 * 60) // 30 minutes
                _ = try await viewModel.snoozeReminder(id: reminder.id, until: snoozeDate)
                dismiss()
            } catch {
                print("Error snoozing reminder: \(error)")
            }
            isSnoozing = false
        }
    }
    
    private func formatRecurrence(_ rule: String) -> String {
        switch rule.lowercased() {
        case "daily", "day":
            return "Daily"
        case "weekly", "week":
            return "Weekly"
        case "monthly", "month":
            return "Monthly"
        case "yearly", "year", "annually":
            return "Yearly"
        default:
            if rule.hasPrefix("every ") {
                return rule.capitalized
            }
            return rule
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    ReminderDetailView(
        reminder: Reminder(
            id: 1,
            userId: 1,
            title: "Team Standup",
            description: "Daily sync meeting with the team",
            dueDate: Date().addingTimeInterval(3600),
            reminderTime: Date().addingTimeInterval(2700),
            isCompleted: false,
            priority: .high,
            status: .pending,
            eventId: nil,
            recurrenceRule: "daily",
            snoozeUntil: nil,
            notificationEnabled: true,
            notificationSound: "default",
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil
        ),
        viewModel: ReminderViewModel()
    )
}

