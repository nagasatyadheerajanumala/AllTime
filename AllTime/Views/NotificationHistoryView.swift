import SwiftUI

/// View displaying notification history
struct NotificationHistoryView: View {
    @StateObject private var historyService = NotificationHistoryService.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            Group {
                if historyService.notifications.isEmpty {
                    emptyStateView
                } else {
                    notificationsList
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !historyService.notifications.isEmpty {
                        Menu {
                            Button("Mark All as Read") {
                                historyService.markAllAsRead()
                            }
                            Button("Clear History", role: .destructive) {
                                historyService.clearHistory()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No Notifications Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Your morning briefings, evening summaries, and reminders will appear here.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(historyService.notificationsGroupedByDate(), id: \.date) { group in
                    Section {
                        ForEach(group.notifications) { notification in
                            NotificationRowView(notification: notification)
                                .onTapGesture {
                                    handleNotificationTap(notification)
                                }
                        }
                    } header: {
                        sectionHeader(for: group.date)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func sectionHeader(for date: Date) -> some View {
        HStack {
            Text(formatSectionDate(date))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }

    // MARK: - Handle Tap

    private func handleNotificationTap(_ notification: NotificationHistoryItem) {
        historyService.markAsRead(notification)

        // Navigate based on destination
        guard let destination = notification.data?.destination else { return }

        dismiss()

        // Post navigation notification after dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch destination {
            case "today":
                NotificationCenter.default.post(name: .navigateToToday, object: nil)
            case "day-review":
                NotificationCenter.default.post(name: .navigateToDayReview, object: nil)
            case "calendar":
                NotificationCenter.default.post(name: .navigateToCalendar, object: nil)
            default:
                break
            }
        }
    }
}

// MARK: - Notification Row View

struct NotificationRowView: View {
    let notification: NotificationHistoryItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(iconBackgroundColor)
                    .frame(width: 40, height: 40)
                Image(systemName: notification.type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatTime(notification.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(notification.isRead ? .secondary : .primary)

                Text(notification.body)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                // Stats for morning/evening notifications
                if let data = notification.data {
                    notificationStats(data)
                }
            }

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func notificationStats(_ data: NotificationData) -> some View {
        HStack(spacing: 12) {
            if let meetings = data.meetingsCount {
                Label("\(meetings) meetings", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let focus = data.focusTimeAvailable, !focus.isEmpty {
                Label(focus, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let completed = data.meetingsCompleted, let total = data.totalMeetings {
                Label("\(completed)/\(total) completed", systemImage: "checkmark.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let percentage = data.completionPercentage {
                Text("\(percentage)%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(percentageColor(percentage))
            }
        }
        .padding(.top, 4)
    }

    private var iconBackgroundColor: Color {
        switch notification.type {
        case .morningBriefing:
            return Color.orange.opacity(0.15)
        case .eveningSummary:
            return Color.indigo.opacity(0.15)
        case .eventReminder:
            return Color.blue.opacity(0.15)
        case .reminderDue:
            return Color.purple.opacity(0.15)
        case .calendarSync:
            return Color.green.opacity(0.15)
        case .system:
            return Color.gray.opacity(0.15)
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .morningBriefing:
            return .orange
        case .eveningSummary:
            return .indigo
        case .eventReminder:
            return .blue
        case .reminderDue:
            return .purple
        case .calendarSync:
            return .green
        case .system:
            return .gray
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func percentageColor(_ percentage: Int) -> Color {
        if percentage >= 75 {
            return .green
        } else if percentage >= 50 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    NotificationHistoryView()
}
