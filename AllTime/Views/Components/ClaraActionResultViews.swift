import SwiftUI

// MARK: - Clara Navigation Helper
/// Dismisses Clara chat and navigates to a specific tab in PremiumTabView
enum ClaraNavigation {
    /// PremiumTabView tab indices (NOT NavigationManager.Tab which has mismatched indices)
    enum PremiumTab: Int {
        case today = 0
        case calendar = 1
        case insights = 2
        case reminders = 3
        case settings = 4
    }

    static func navigateTo(tab: PremiumTab) {
        NotificationCenter.default.post(
            name: .claraDismissAndNavigate,
            object: nil,
            userInfo: ["tabIndex": tab.rawValue]
        )
    }
}

// MARK: - Tool Result Card (NEW - function calling system)
/// Dispatches tool results from the new function calling system to appropriate views
struct ClaraToolResultCardView: View {
    let result: ToolResultForUI

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch result.toolName {
            case "get_events", "get_upcoming_events":
                if let events = result.data?.events, !events.isEmpty {
                    ToolEventsResultView(events: events, date: result.data?.date)
                }

            case "get_free_slots":
                if let slots = result.data?.freeSlots, !slots.isEmpty {
                    FreeSlotResultView(slots: slots, date: result.data?.date,
                                       totalMinutes: result.data?.totalFreeMinutes)
                }

            case "get_tasks":
                if let tasks = result.data?.tasks, !tasks.isEmpty {
                    TasksResultView(tasks: tasks)
                }

            case "get_day_schedule":
                if let data = result.data {
                    ScheduleResultView(payload: data)
                }

            case "get_reminders":
                if let reminders = result.data?.reminders, !reminders.isEmpty {
                    RemindersResultView(reminders: reminders)
                }

            case "get_health_summary":
                if let data = result.data {
                    HealthSummaryResultView(payload: data)
                }

            case "search_places":
                if let places = result.data?.places, !places.isEmpty {
                    PlacesResultView(places: places)
                }

            case "create_event":
                if result.data?.success == true {
                    EventCreatedView(
                        title: result.data?.title ?? "Event",
                        date: result.data?.date,
                        startTime: result.data?.startTime,
                        endTime: result.data?.endTime,
                        location: result.data?.location
                    )
                }

            case "edit_event":
                if result.data?.success == true {
                    EventEditedView(
                        title: result.data?.title ?? "Event",
                        oldDate: result.data?.oldDate,
                        oldTime: result.data?.oldTime,
                        newDate: result.data?.newDate,
                        newTime: result.data?.newTime
                    )
                }

            case "delete_event":
                if result.data?.success == true {
                    EventDeletedView(
                        title: result.data?.title ?? "Event",
                        date: result.data?.date,
                        time: result.data?.time ?? result.data?.startTime
                    )
                }

            case "find_mutual_free_time":
                if let data = result.data, let slots = data.slots, !slots.isEmpty {
                    MutualFreeTimeSlotsView(payload: data)
                }

            case "send_scheduling_proposal":
                if result.data?.success == true {
                    SchedulingBookedView(payload: result.data!)
                }

            case "get_network_connections":
                if let data = result.data, let connections = data.connections, !connections.isEmpty {
                    NetworkConnectionsResultView(connections: connections)
                }

            case "schedule_with_connection":
                if let data = result.data, let slots = data.slots, !slots.isEmpty {
                    MutualFreeTimeSlotsView(payload: data)
                } else if let data = result.data, let error = data.error {
                    HStack(spacing: 8) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.amber)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                    .padding(12)
                    .calmCard(padding: 0)
                }

            case "create_task", "complete_task", "create_reminder":
                // Simple confirmations handled by Clara's text response
                EmptyView()

            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Legacy Action Result Container
/// Displays the appropriate view based on legacy action type (backward compat)
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

            if !tasks.isEmpty {
                Button(action: {
                    ClaraNavigation.navigateTo(tab: .reminders)
                }) {
                    HStack(spacing: 4) {
                        Text("View all tasks")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.violet)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskData

    var body: some View {
        Button(action: {
            ClaraNavigation.navigateTo(tab: .reminders)
        }) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(10)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
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

            // View in Calendar button
            Button(action: {
                ClaraNavigation.navigateTo(tab: .calendar)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                    Text("View in Calendar")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(DesignSystem.Colors.emerald)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.emerald.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
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
        VStack(spacing: 8) {
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

            Button(action: {
                ClaraNavigation.navigateTo(tab: .calendar)
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                    Text("View in Calendar")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(DesignSystem.Colors.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.blue.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
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

            if !reminders.isEmpty {
                Button(action: {
                    ClaraNavigation.navigateTo(tab: .reminders)
                }) {
                    HStack(spacing: 4) {
                        Text("View all reminders")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.violet)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

struct ReminderRow: View {
    let reminder: ReminderData

    var body: some View {
        Button(action: {
            ClaraNavigation.navigateTo(tab: .reminders)
        }) {
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

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(10)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Tool Events Result View (from get_events/get_upcoming_events)
struct ToolEventsResultView: View {
    let events: [ToolEventData]
    let date: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = date {
                Text(formatDate(date))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .textCase(.uppercase)
                    .padding(.bottom, 4)
            }

            ForEach(events.prefix(8)) { event in
                Button(action: {
                    ClaraNavigation.navigateTo(tab: .calendar)
                }) {
                    HStack(spacing: 10) {
                        // Time column
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(formatTime(event.startTime ?? ""))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.violet)
                        }
                        .frame(width: 50, alignment: .trailing)

                        // Divider line
                        Rectangle()
                            .fill(DesignSystem.Colors.violet.opacity(0.3))
                            .frame(width: 2)
                            .frame(maxHeight: .infinity)

                        // Event info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title ?? "Event")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                                .lineLimit(1)

                            if let location = event.location, !location.isEmpty {
                                Text(location)
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        if event.allDay == true {
                            Text("All day")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.blue.opacity(0.15))
                                .clipShape(Capsule())
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if events.count > 8 {
                Text("+ \(events.count - 8) more events")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Button(action: {
                ClaraNavigation.navigateTo(tab: .calendar)
            }) {
                HStack(spacing: 4) {
                    Text("Open Calendar")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.violet)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

// MARK: - Free Slot Result View
struct FreeSlotResultView: View {
    let slots: [FreeSlotData]
    let date: String?
    let totalMinutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.emerald)
                Text("Available Time")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                if let total = totalMinutes {
                    Text("\(total / 60)h \(total % 60)m free")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.emerald)
                }
            }

            ForEach(slots.prefix(5)) { slot in
                HStack(spacing: 12) {
                    // Time range
                    Text("\(formatTime(slot.startTime)) – \(formatTime(slot.endTime))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    // Duration badge
                    Text("\(slot.durationMinutes) min")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.emerald)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(DesignSystem.Colors.emerald.opacity(0.12))
                        .clipShape(Capsule())
                }
                .padding(.vertical, 4)
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.emerald.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.emerald.opacity(0.2), lineWidth: 1)
        )
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

// MARK: - Schedule Result View (from get_day_schedule)
struct ScheduleResultView: View {
    let payload: ToolResultPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with stats
            HStack {
                Image(systemName: "calendar.day.timeline.leading")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("Day Schedule")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
            }

            // Stats row
            HStack(spacing: 16) {
                if let eventCount = payload.eventCount {
                    ScheduleStatPill(icon: "calendar", value: "\(eventCount)", label: "events", color: DesignSystem.Colors.blue)
                }
                if let meetingMin = payload.totalMeetingMinutes, meetingMin > 0 {
                    ScheduleStatPill(icon: "clock", value: "\(meetingMin / 60)h \(meetingMin % 60)m", label: "meetings", color: DesignSystem.Colors.amber)
                }
                if let freeMin = payload.totalFreeMinutes, freeMin > 0 {
                    ScheduleStatPill(icon: "sparkles", value: "\(freeMin / 60)h \(freeMin % 60)m", label: "free", color: DesignSystem.Colors.emerald)
                }
            }

            // Events
            if let events = payload.events, !events.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(events.prefix(6)) { event in
                        Button(action: {
                            ClaraNavigation.navigateTo(tab: .calendar)
                        }) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(event.allDay == true ? DesignSystem.Colors.blue : DesignSystem.Colors.violet)
                                    .frame(width: 6, height: 6)
                                Text(formatTime(event.startTime ?? ""))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                                    .frame(width: 55, alignment: .leading)
                                Text(event.title ?? "Event")
                                    .font(.system(size: 13))
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Free blocks
            if let freeBlocks = payload.freeBlocks, !freeBlocks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free windows")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.emerald)
                        .textCase(.uppercase)

                    ForEach(freeBlocks.prefix(3)) { block in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.emerald)
                            Text("\(formatTime(block.startTime)) – \(formatTime(block.endTime))")
                                .font(.system(size: 12))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                            Text("(\(block.durationMinutes)m)")
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }
                }
            }

            // Open Calendar action
            Button(action: {
                ClaraNavigation.navigateTo(tab: .calendar)
            }) {
                HStack(spacing: 4) {
                    Text("Open Calendar")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DesignSystem.Colors.violet)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.violet.opacity(0.15), lineWidth: 1)
        )
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

/// Small stat pill used in ScheduleResultView
struct ScheduleStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Health Summary Result View
struct HealthSummaryResultView: View {
    let payload: ToolResultPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignSystem.Colors.errorRed)
                Text("Health Summary")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
            }

            // Multi-day summary
            if let summary = payload.summary {
                HStack(spacing: 16) {
                    if let steps = summary.avgSteps {
                        HealthMetricView(icon: "figure.walk", label: "Avg Steps",
                                         value: String(format: "%.0f", steps),
                                         color: DesignSystem.Colors.emerald)
                    }
                    if let sleep = summary.avgSleepHours {
                        HealthMetricView(icon: "moon.fill", label: "Avg Sleep",
                                         value: String(format: "%.1fh", sleep),
                                         color: DesignSystem.Colors.indigo)
                    }
                    if let days = summary.daysWithData {
                        HealthMetricView(icon: "calendar", label: "Days",
                                         value: "\(days)",
                                         color: DesignSystem.Colors.blue)
                    }
                }
            }

            // Daily data
            if let dailyData = payload.dailyData, !dailyData.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(dailyData.prefix(5)) { day in
                        HStack(spacing: 12) {
                            Text(formatShortDate(day.date ?? ""))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                                .frame(width: 50, alignment: .leading)

                            if let steps = day.steps {
                                HStack(spacing: 2) {
                                    Image(systemName: "figure.walk")
                                        .font(.system(size: 10))
                                    Text("\(steps)")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(DesignSystem.Colors.emerald)
                                .frame(width: 65, alignment: .leading)
                            }

                            if let sleep = day.sleepHours {
                                HStack(spacing: 2) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 10))
                                    Text(String(format: "%.1fh", sleep))
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(DesignSystem.Colors.indigo)
                                .frame(width: 55, alignment: .leading)
                            }

                            if let hr = day.restingHeartRate {
                                HStack(spacing: 2) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 10))
                                    Text("\(hr)")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(DesignSystem.Colors.errorRed)
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(DesignSystem.Colors.errorRed.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.errorRed.opacity(0.15), lineWidth: 1)
        )
    }

    private func formatShortDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }
}

/// Individual health metric display
struct HealthMetricView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Network Views

struct NetworkConnectionsResultView: View {
    let connections: [NetworkConnectionData]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("Your Network")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text("\(connections.count) connections")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            ForEach(connections) { connection in
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.Colors.violet.opacity(0.6))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(connection.fullName ?? connection.email ?? "Unknown")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if let interests = connection.sharedInterests, !interests.isEmpty {
                            Text(interests.joined(separator: ", "))
                                .font(.system(size: 11))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding(14)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.violet.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Social Scheduling Views

/// Card showing ranked available time slots from mutual free time search
struct MutualFreeTimeSlotsView: View {
    let payload: ToolResultPayload
    @EnvironmentObject private var claraViewModel: ClaraChatViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("Available Times")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                if let checked = payload.calendarsChecked {
                    Text("\(checked) calendars")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            // External participant note
            if let external = payload.externalParticipants, !external.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("\(external.joined(separator: ", ")) not on AllTime — times based on your calendar")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(8)
                .background(DesignSystem.Colors.cardBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Slot rows
            if let slots = payload.slots {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    SchedulingSlotRow(slot: slot, index: index, isTop: index == 0) {
                        claraViewModel.sendMessage("Book slot \(index + 1)")
                    }
                }
            }
        }
        .padding(14)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.violet.opacity(0.2), lineWidth: 1)
        )
    }
}

/// Single slot row with day, time, score badge, and Book button
struct SchedulingSlotRow: View {
    let slot: SchedulingSlotData
    let index: Int
    let isTop: Bool
    let onBook: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Day + date
            VStack(alignment: .leading, spacing: 2) {
                if let dow = slot.dayOfWeek {
                    Text(dow.prefix(3).capitalized)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                if let date = slot.date {
                    Text(formatShortDate(date))
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
            .frame(width: 50, alignment: .leading)

            // Time range
            if let start = slot.startTime, let end = slot.endTime {
                Text("\(start) – \(end)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Spacer()

            // Best badge for top slot
            if isTop {
                Text("Best")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.emerald)
                    .clipShape(Capsule())
            }

            // Book button
            Button(action: onBook) {
                Text("Book")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.violet)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .background(DesignSystem.Colors.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatShortDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
        return dateStr
    }
}

/// Confirmation card after a scheduling proposal is booked
struct SchedulingBookedView: View {
    let payload: ToolResultPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Success header
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(DesignSystem.Colors.emerald)
                Text("Booked!")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Divider()

            // Event details
            if let title = payload.title {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.violet)
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
            }

            if let date = payload.date {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text("\(formatFullDate(date))")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    if let start = payload.startTime, let end = payload.endTime {
                        Text("\(start) – \(end)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }
            }

            if let loc = payload.location, !loc.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    Text(loc)
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            // Invite confirmation
            if payload.attendeesNotified == true {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.emerald)
                    Text("Calendar invites sent to all participants")
                        .font(.system(size: 11))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(.top, 4)
            }

            // View in Calendar button
            Button {
                ClaraNavigation.navigateTo(tab: .calendar)
            } label: {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("View in Calendar")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(DesignSystem.Colors.violet)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(DesignSystem.Colors.violet.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(14)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignSystem.Colors.emerald.opacity(0.3), lineWidth: 1)
        )
    }

    private func formatFullDate(_ dateStr: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateStr) {
            formatter.dateFormat = "EEEE, MMM d"
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
