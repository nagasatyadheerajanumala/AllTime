import SwiftUI

// MARK: - Action Result Container
/// Displays the appropriate view based on action type
struct ClaraActionResultView: View {
    let actionResult: ActionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch actionResult.actionType {
            case "search_places":
                if let places = actionResult.data?.places, !places.isEmpty {
                    PlacesResultView(places: places)
                }

            case "get_tasks":
                if let tasks = actionResult.data?.tasks, !tasks.isEmpty {
                    TasksResultView(tasks: tasks)
                }

            case "create_event":
                if actionResult.success {
                    EventCreatedView(
                        title: actionResult.data?.title ?? "Event",
                        date: actionResult.data?.date,
                        startTime: actionResult.data?.startTime,
                        endTime: actionResult.data?.endTime,
                        location: actionResult.data?.location,
                        mapsUrl: actionResult.data?.mapsUrl
                    )
                }

            case "get_itinerary":
                if let slots = actionResult.data?.timeSlots, !slots.isEmpty {
                    ItineraryResultView(
                        timeSlots: slots,
                        summary: actionResult.data?.summary
                    )
                }

            case "check_blockers":
                if let blockers = actionResult.data?.blockers {
                    BlockersResultView(blockers: blockers)
                }

            case "get_reminders":
                if let reminders = actionResult.data?.reminders, !reminders.isEmpty {
                    RemindersResultView(reminders: reminders)
                }

            case "edit_event":
                if actionResult.success {
                    EventEditedView(
                        title: actionResult.data?.title ?? "Event",
                        oldDate: actionResult.data?.oldDate,
                        oldTime: actionResult.data?.oldTime,
                        newDate: actionResult.data?.newDate,
                        newTime: actionResult.data?.newTime
                    )
                }

            case "delete_event":
                if actionResult.success {
                    EventDeletedView(
                        title: actionResult.data?.title ?? "Event",
                        date: actionResult.data?.date,
                        time: actionResult.data?.startTime
                    )
                }

            case "create_task", "complete_task", "create_reminder":
                // Simple confirmation - handled by message text
                EmptyView()

            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Places Result View
struct PlacesResultView: View {
    let places: [PlaceData]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(places.prefix(5)) { place in
                PlaceCard(place: place)
            }
        }
    }
}

struct PlaceCard: View {
    let place: PlaceData

    var body: some View {
        Button(action: openInMaps) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: place.icon ?? "mappin.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.violet)
                    .frame(width: 40, height: 40)
                    .background(DesignSystem.Colors.violet.opacity(0.15))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let rating = place.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }

                        if let distance = place.distanceKm {
                            Text(String(format: "%.1f km", distance))
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }

                        if let price = place.priceLevel {
                            Text(price)
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }
                }

                Spacer()

                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.violet)
            }
            .padding(12)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func openInMaps() {
        if let urlString = place.mapsUrl, let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        } else if let lat = place.latitude, let lon = place.longitude {
            let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Tasks Result View
struct TasksResultView: View {
    let tasks: [TaskData]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tasks.prefix(5)) { task in
                TaskRow(task: task)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.completed == true ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundColor(task.completed == true ? DesignSystem.Colors.emerald : DesignSystem.Colors.tertiaryText)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .strikethrough(task.completed == true)

                if let dueDate = task.dueDate {
                    Text("Due: \(formatDate(dueDate))")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Spacer()

            if let priority = task.priority, priority == "HIGH" {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.amber)
            }
        }
        .padding(10)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }
}

// MARK: - Event Created View
struct EventCreatedView: View {
    let title: String
    let date: String?
    let startTime: String?
    let endTime: String?
    let location: String?
    let mapsUrl: String?

    init(title: String, date: String?, startTime: String?, endTime: String?, location: String? = nil, mapsUrl: String? = nil) {
        self.title = title
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.mapsUrl = mapsUrl
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main event card
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.emerald)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Event Added")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.emerald)

                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let date = date, let start = startTime {
                        Text("\(formatDate(date)) at \(formatTime(start))")
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()
            }

            // Location with Maps link (if restaurant event)
            if let location = location {
                Button(action: openInMaps) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(DesignSystem.Colors.violet)

                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(2)

                        Spacer()

                        if mapsUrl != nil {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.violet)
                        }
                    }
                    .padding(10)
                    .background(DesignSystem.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(14)
        .background(DesignSystem.Colors.emerald.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.emerald.opacity(0.3), lineWidth: 1)
        )
    }

    private func openInMaps() {
        if let urlString = mapsUrl, let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }

    private func formatTime(_ timeStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let time = formatter.date(from: timeStr) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: time)
        }
        return timeStr
    }
}

// MARK: - Event Edited View
struct EventEditedView: View {
    let title: String
    let oldDate: String?
    let oldTime: String?
    let newDate: String?
    let newTime: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text("Event Rescheduled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.blue)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let newDate = newDate, let newTime = newTime {
                    Text("New: \(formatDate(newDate)) at \(formatTime(newTime))")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                if let oldDate = oldDate, let oldTime = oldTime {
                    Text("Was: \(formatDate(oldDate)) at \(formatTime(oldTime))")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .strikethrough()
                }
            }

            Spacer()
        }
        .padding(14)
        .background(DesignSystem.Colors.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }

    private func formatTime(_ timeStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let time = formatter.date(from: timeStr) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: time)
        }
        return timeStr
    }
}

// MARK: - Event Deleted View
struct EventDeletedView: View {
    let title: String
    let date: String?
    let time: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.minus")
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.amber)

            VStack(alignment: .leading, spacing: 4) {
                Text("Event Cancelled")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.amber)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .strikethrough()

                if let date = date {
                    HStack(spacing: 4) {
                        Text(formatDate(date))
                        if let time = time {
                            Text("at \(formatTime(time))")
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Spacer()
        }
        .padding(14)
        .background(DesignSystem.Colors.amber.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.amber.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }

    private func formatTime(_ timeStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        if let time = formatter.date(from: timeStr) {
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: time)
        }
        return timeStr
    }
}

// MARK: - Itinerary Result View
struct ItineraryResultView: View {
    let timeSlots: [TimeSlotData]
    let summary: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = summary {
                Text(summary)
                    .font(.system(size: 13))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.bottom, 4)
            }

            ForEach(timeSlots.prefix(6)) { slot in
                ItinerarySlotRow(slot: slot)
            }

            if timeSlots.count > 6 {
                Text("+ \(timeSlots.count - 6) more...")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
    }
}

struct ItinerarySlotRow: View {
    let slot: TimeSlotData

    var iconName: String {
        switch slot.category {
        case "meeting": return "calendar"
        case "focus": return "brain.head.profile"
        case "break": return "cup.and.saucer"
        case "health": return "figure.walk"
        case "planning": return "checklist"
        default: return "clock"
        }
    }

    var iconColor: Color {
        switch slot.category {
        case "meeting": return DesignSystem.Colors.blue
        case "focus": return DesignSystem.Colors.violet
        case "break": return DesignSystem.Colors.amber
        case "health": return DesignSystem.Colors.emerald
        default: return DesignSystem.Colors.secondaryText
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Time
            Text(slot.startTime)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .frame(width: 50, alignment: .trailing)

            // Icon
            Image(systemName: iconName)
                .font(.system(size: 14))
                .foregroundColor(iconColor)
                .frame(width: 24)

            // Activity
            Text(slot.activity)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer()

            // Existing badge
            if slot.isExisting == true {
                Text("Calendar")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Blockers Result View
struct BlockersResultView: View {
    let blockers: [BlockerData]

    var body: some View {
        if blockers.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.emerald)
                Text("No schedule conflicts found")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(12)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(blockers) { blocker in
                    BlockerRow(blocker: blocker)
                }
            }
        }
    }
}

struct BlockerRow: View {
    let blocker: BlockerData

    var severityColor: Color {
        switch blocker.severity {
        case "critical": return DesignSystem.Colors.errorRed
        case "warning": return DesignSystem.Colors.amber
        default: return DesignSystem.Colors.blue
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(severityColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(blocker.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(blocker.detail)
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            Spacer()
        }
        .padding(10)
        .background(severityColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Reminders Result View
struct RemindersResultView: View {
    let reminders: [ReminderData]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(reminders.prefix(5)) { reminder in
                ReminderRow(reminder: reminder)
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: ReminderData

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.fill")
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.violet)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let date = reminder.dueDate {
                    Text(formatDate(date))
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            Spacer()
        }
        .padding(10)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }
}

// MARK: - Preview
#Preview("Places Result") {
    VStack {
        PlacesResultView(places: [
            PlaceData(name: "The Grill Room", address: "123 Main St", rating: 4.5, priceLevel: "$$", distanceKm: 0.8, latitude: nil, longitude: nil, googlePlaceId: "abc", mapsUrl: nil, icon: "fork.knife"),
            PlaceData(name: "Coffee House", address: "456 Oak Ave", rating: 4.2, priceLevel: "$", distanceKm: 1.2, latitude: nil, longitude: nil, googlePlaceId: "def", mapsUrl: nil, icon: "cup.and.saucer.fill")
        ])
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
