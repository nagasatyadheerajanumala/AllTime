import SwiftUI

struct ReminderRowView: View {
    let reminder: Reminder
    let onComplete: () -> Void
    let onSnooze: () -> Void
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    private var isOverdue: Bool {
        reminder.dueDate < Date() && reminder.status == .pending
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox/Status indicator
            Button(action: onComplete) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(reminder.isCompleted ? .green : (isOverdue ? .red : .gray))
            }
            .buttonStyle(PlainButtonStyle())
            
            // Reminder content
            VStack(alignment: .leading, spacing: 4) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .strikethrough(reminder.isCompleted)
                    .foregroundColor(reminder.isCompleted ? .secondary : (isOverdue ? .red : .primary))
                    .lineLimit(2)
                
                if let description = reminder.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Due date
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(Self.dateFormatter.string(from: reminder.dueDate))
                            .font(.caption)
                    }
                    .foregroundColor(isOverdue ? .red : .secondary)
                    
                    // Priority badge
                    if let priority = reminder.priority {
                        PriorityBadge(priority: priority)
                    }
                    
                    // Recurrence indicator
                    if reminder.recurrenceRule != nil {
                        Image(systemName: "repeat")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Snooze button
            if !reminder.isCompleted && reminder.status != .snoozed {
                Button(action: onSnooze) {
                    Image(systemName: "moon.zzz")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: ReminderPriority
    
    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(priorityColor(priority))
            )
            .foregroundColor(.white)
    }
    
    private func priorityColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .urgent: return .purple
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ReminderRowView(
            reminder: Reminder(
                id: 1,
                userId: 1,
                title: "Team Standup",
                description: "Daily sync meeting",
                dueDate: Date().addingTimeInterval(3600),
                reminderTime: nil,
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
            onComplete: {},
            onSnooze: {}
        )
        
        ReminderRowView(
            reminder: Reminder(
                id: 2,
                userId: 1,
                title: "Overdue Task",
                description: nil,
                dueDate: Date().addingTimeInterval(-3600),
                reminderTime: nil,
                isCompleted: false,
                priority: .urgent,
                status: .pending,
                eventId: nil,
                recurrenceRule: nil,
                snoozeUntil: nil,
                notificationEnabled: true,
                notificationSound: "default",
                createdAt: Date(),
                updatedAt: Date(),
                completedAt: nil
            ),
            onComplete: {},
            onSnooze: {}
        )
    }
    .padding()
}

