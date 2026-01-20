import SwiftUI

struct ReminderRowView: View {
    let reminder: Reminder
    let onComplete: () -> Void
    let onSnooze: () -> Void
    var onDelete: (() -> Void)? = nil

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Returns a friendly, relative date string
    private var friendlyDateString: String {
        let calendar = Calendar.current
        let now = Date()
        let dueDate = reminder.dueDate

        if calendar.isDateInToday(dueDate) {
            return "Today, \(Self.timeFormatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow, \(Self.timeFormatter.string(from: dueDate))"
        } else if calendar.isDateInYesterday(dueDate) {
            return "Yesterday"
        } else if dueDate < now {
            let days = calendar.dateComponents([.day], from: dueDate, to: now).day ?? 0
            if days == 1 {
                return "1 day ago"
            } else if days < 7 {
                return "\(days) days ago"
            }
        } else {
            let days = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
            if days < 7 {
                let weekday = calendar.component(.weekday, from: dueDate)
                let weekdayName = calendar.weekdaySymbols[weekday - 1]
                return weekdayName
            }
        }
        return Self.dateFormatter.string(from: dueDate)
    }

    private var needsAttention: Bool {
        reminder.dueDate < Date() && reminder.status == .pending
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Simple checkbox
            Button(action: onComplete) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(reminder.isCompleted ? DesignSystem.Colors.emerald : DesignSystem.Colors.tertiaryText)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.top, 2)

            // Note content - clean and simple
            VStack(alignment: .leading, spacing: 6) {
                // Title - prominent
                Text(reminder.title)
                    .font(.system(size: 16, weight: .regular))
                    .strikethrough(reminder.isCompleted, color: DesignSystem.Colors.tertiaryText)
                    .foregroundColor(reminder.isCompleted ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description - if present
                if let description = reminder.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                // Subtle metadata row
                HStack(spacing: 12) {
                    // Date - friendly format
                    Text(friendlyDateString)
                        .font(.system(size: 12))
                        .foregroundColor(needsAttention ? DesignSystem.Colors.warning : DesignSystem.Colors.secondaryText)

                    // Priority indicator - subtle dot or text
                    if let priority = reminder.priority, priority != .low {
                        PriorityIndicator(priority: priority)
                    }

                    // Recurring indicator
                    if reminder.recurrenceRule != nil {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text("Repeats")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()
                }
            }

            Spacer(minLength: 0)

            // Minimal action buttons
            if !reminder.isCompleted {
                HStack(spacing: 16) {
                    if reminder.status != .snoozed {
                        Button(action: onSnooze) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Priority Indicator (Subtle, non-alarming)

struct PriorityIndicator: View {
    let priority: ReminderPriority

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priorityColor)
                .frame(width: 6, height: 6)

            Text(priority.displayName)
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }

    private var priorityColor: Color {
        switch priority {
        case .low: return DesignSystem.Colors.tertiaryText
        case .medium: return DesignSystem.Colors.primary
        case .high: return Color(hex: "5856D6")     // Indigo - important
        case .urgent: return DesignSystem.Colors.warning   // Orange - time-sensitive
        }
    }
}

// MARK: - Legacy Priority Badge (kept for compatibility)

struct PriorityBadge: View {
    let priority: ReminderPriority

    var body: some View {
        Text(priority.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(priorityColor(priority).opacity(0.15))
            )
            .foregroundColor(priorityColor(priority))
    }

    private func priorityColor(_ priority: ReminderPriority) -> Color {
        switch priority {
        case .low: return Color(hex: "8E8E93")      // Gray
        case .medium: return Color(hex: "007AFF")   // Blue
        case .high: return Color(hex: "5856D6")     // Indigo
        case .urgent: return DesignSystem.Colors.warning   // Orange
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ReminderRowView(
            reminder: Reminder(
                id: 1,
                userId: 1,
                title: "Review the quarterly report",
                description: "Check the numbers and add comments",
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
                title: "Pick up groceries on the way home",
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
            onSnooze: {},
            onDelete: {}
        )

        ReminderRowView(
            reminder: Reminder(
                id: 3,
                userId: 1,
                title: "Call Mom",
                description: "Wish her happy birthday",
                dueDate: Date(),
                reminderTime: nil,
                isCompleted: true,
                priority: .medium,
                status: .completed,
                eventId: nil,
                recurrenceRule: nil,
                snoozeUntil: nil,
                notificationEnabled: true,
                notificationSound: "default",
                createdAt: Date(),
                updatedAt: Date(),
                completedAt: Date()
            ),
            onComplete: {},
            onSnooze: {}
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
