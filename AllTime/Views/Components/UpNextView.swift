import SwiftUI
import EventKit

// MARK: - Up Next Section View (Intelligent Suggestions)
struct UpNextSectionView: View {
    @StateObject private var viewModel = UpNextViewModel()
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with summary
            headerView

            // Quick Add Input
            QuickAddInputView(
                text: $viewModel.quickAddText,
                deadline: $viewModel.quickAddDeadline,
                isLoading: viewModel.isAddingTask,
                isFocused: $isInputFocused
            ) {
                Task {
                    await viewModel.quickAdd()
                }
            }

            // Intelligent Suggestions or Empty State
            if viewModel.hasUpNextItems {
                intelligentSuggestionsView
            } else if viewModel.hasTasks {
                // Fallback to legacy tasks if no intelligent suggestions
                legacyTasksView
            } else if !viewModel.isLoading {
                EmptyUpNextView(message: viewModel.summaryMessage)
            }

            // Error message
            if let error = viewModel.error {
                Text(error)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .task {
            await viewModel.loadUpNext()
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan Your Day")
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let message = viewModel.summaryMessage {
                    Text(message)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer()

            // Stats badges
            HStack(spacing: 8) {
                if viewModel.meetingCount > 0 {
                    StatBadge(
                        icon: "calendar",
                        text: "\(viewModel.meetingCount)",
                        color: .blue
                    )
                }

                if viewModel.totalFreeMinutes > 0 {
                    StatBadge(
                        icon: "clock",
                        text: "\(viewModel.totalFreeMinutes / 60)h free",
                        color: .green
                    )
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }

    // MARK: - Intelligent Suggestions List
    private var intelligentSuggestionsView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.upNextItems) { item in
                UpNextItemRowView(item: item)
            }
        }
    }

    // MARK: - Legacy Tasks List (Fallback)
    private var legacyTasksView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(viewModel.tasks, id: \.id) { task in
                TaskRowView(task: task) {
                    Task {
                        await viewModel.completeTask(task)
                    }
                } onDelete: {
                    Task {
                        await viewModel.deleteTask(task)
                    }
                }
            }
        }
    }
}

// MARK: - Up Next Item Row (Intelligent Suggestion)
struct UpNextItemRowView: View {
    let item: UpNextItem

    init(item: UpNextItem) {
        self.item = item
        print("📦 UpNextItemRowView INIT for '\(item.title)' type=\(item.type) primaryAction=\(item.primaryAction ?? "nil") startTime=\(String(describing: item.startTime))")
    }

    @State private var isBlockingTime = false
    @State private var showBlockTimeSuccess = false
    @State private var showBlockTimeError = false
    @State private var blockTimeMessage = ""
    @State private var showFoodRecommendations = false
    @State private var showWalkRecommendations = false
    @State private var showAddToListOptions = false
    @State private var showReminderSuccess = false
    @State private var reminderMessage = ""
    @State private var showBlockConfirmation = false

    private let eventStore = EKEventStore()

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Main row content
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Icon
                ZStack {
                    Circle()
                        .fill(item.displayColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: item.displayIcon)
                        .font(.system(size: 18))
                        .foregroundColor(item.displayColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.title)
                            .font(DesignSystem.Typography.body.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if item.confidenceLevel == .high {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                    }

                    // Time and duration
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Time label - USE THE ACTUAL TIME FROM THE ITEM
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(item.displayTimeLabel)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                        // Duration
                        if !item.displayDuration.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "timer")
                                    .font(.system(size: 10))
                                Text(item.displayDuration)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }

                    // Reason
                    if let reason = item.reason {
                        Text(reason)
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Action button
                actionButton
            }

            // Description (expandable in future)
            if let description = item.description {
                Text(description)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(2)
                    .padding(.leading, 48)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .alert("\(item.title) Blocked!", isPresented: $showBlockTimeSuccess) {
            Button("OK") {}
        } message: {
            Text(blockTimeMessage)
        }
        .alert("Unable to Block Time", isPresented: $showBlockTimeError) {
            Button("OK") {}
        } message: {
            Text(blockTimeMessage)
        }
        .sheet(isPresented: $showFoodRecommendations) {
            FoodRecommendationsView()
        }
        .sheet(isPresented: $showWalkRecommendations) {
            WalkRecommendationsView()
        }
        .confirmationDialog("Block Time", isPresented: $showBlockConfirmation, titleVisibility: .visible) {
            Button("Add to Calendar") {
                print("📅 CONFIRMATION: Add to Calendar tapped for '\(item.title)'")
                blockTime()
            }
            Button("Add to Reminders") {
                print("⏰ CONFIRMATION: Add to Reminders tapped for '\(item.title)'")
                addToReminders()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Block '\(item.title)' on your calendar?")
        }
        .alert("Added to Reminders!", isPresented: $showReminderSuccess) {
            Button("OK") {}
        } message: {
            Text(reminderMessage)
        }
    }

    // MARK: - Action Button
    @ViewBuilder
    private var actionButton: some View {
        let _ = print("🔵 actionButton for '\(item.title)': primaryAction=\(item.primaryAction ?? "nil"), isBlockingTime=\(isBlockingTime)")

        if isBlockingTime {
            ProgressView()
                .scaleEffect(0.8)
        } else {
            // Special actions for food/walk recommendations
            if item.primaryAction == "view_places" || item.primaryAction == "view_food_places" {
                Button {
                    showFoodRecommendations = true
                } label: {
                    Text("View Places")
                        .font(DesignSystem.Typography.caption.weight(.medium))
                        .foregroundColor(item.displayColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(item.displayColor.opacity(0.15))
                        .cornerRadius(8)
                }
            } else if item.primaryAction == "view_routes" || item.primaryAction == "view_walk_routes" {
                Button {
                    showWalkRecommendations = true
                } label: {
                    Text("View Routes")
                        .font(DesignSystem.Typography.caption.weight(.medium))
                        .foregroundColor(item.displayColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(item.displayColor.opacity(0.15))
                        .cornerRadius(8)
                }
            } else {
                // Block Time button - same structure as View Places/View Routes
                Button {
                    showBlockConfirmation = true
                } label: {
                    Text("Block Time")
                        .font(DesignSystem.Typography.caption.weight(.medium))
                        .foregroundColor(item.displayColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(item.displayColor.opacity(0.15))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Handle Action
    private func handleAction() {
        switch item.primaryAction {
        case "block_time":
            blockTime()
        case "view_places", "view_food_places":
            showFoodRecommendations = true
        case "view_routes", "view_walk_routes":
            showWalkRecommendations = true
        default:
            blockTime()
        }
    }

    // MARK: - Block Time on Calendar
    private func blockTime() {
        print("🔵 blockTime() CALLED for item: '\(item.title)'")
        print("   - primaryAction: \(item.primaryAction ?? "nil")")
        print("   - item.startTime: \(String(describing: item.startTime))")
        print("   - item.timeLabel: \(item.timeLabel ?? "nil")")
        print("   - isBlockingTime: \(isBlockingTime)")

        guard !isBlockingTime else {
            print("⚠️ blockTime() early return - isBlockingTime is true")
            return
        }

        // Try to get start time from item, or parse from timeLabel, or use next available slot
        let startTime: Date
        let endTime: Date

        if let itemStartTime = item.startTime {
            startTime = itemStartTime
            endTime = item.endTime ?? itemStartTime.addingTimeInterval(Double(item.durationMinutes ?? 60) * 60)
        } else if let parsedTime = parseTimeFromLabel(item.timeLabel) {
            startTime = parsedTime
            endTime = parsedTime.addingTimeInterval(Double(item.durationMinutes ?? 60) * 60)
        } else {
            // Fallback: use current time rounded to next 15-minute slot
            let now = Date()
            let calendar = Calendar.current
            let minute = calendar.component(.minute, from: now)
            let roundedMinute = ((minute / 15) + 1) * 15
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            components.minute = roundedMinute % 60
            if roundedMinute >= 60 {
                components.hour = (components.hour ?? 0) + 1
            }
            startTime = calendar.date(from: components) ?? now
            endTime = startTime.addingTimeInterval(Double(item.durationMinutes ?? 60) * 60)
        }

        // Debug: Print detailed time info
        let debugFormatter = DateFormatter()
        debugFormatter.dateStyle = .medium
        debugFormatter.timeStyle = .long
        debugFormatter.timeZone = TimeZone.current
        print("🔵 UpNextItemRowView: Blocking time for '\(item.title)'")
        print("   - Item startTime raw: \(startTime)")
        print("   - Item endTime raw: \(endTime)")
        print("   - Start (local): \(debugFormatter.string(from: startTime))")
        print("   - End (local): \(debugFormatter.string(from: endTime))")
        print("   - Current timezone: \(TimeZone.current.identifier)")

        isBlockingTime = true

        // Request calendar access and create event
        Task {
            do {
                let granted = await requestCalendarAccess()
                guard granted else {
                    await MainActor.run {
                        isBlockingTime = false
                        blockTimeMessage = "Calendar access is required to block time. Please enable it in Settings."
                        showBlockTimeError = true
                    }
                    return
                }

                // Create the calendar event
                try await createCalendarEvent(
                    title: item.title,
                    startDate: startTime,
                    endDate: endTime,
                    notes: item.description
                )

                await MainActor.run {
                    isBlockingTime = false
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    blockTimeMessage = "Blocked \(formatter.string(from: startTime)) - \(formatter.string(from: endTime)) on your calendar."
                    showBlockTimeSuccess = true
                }
            } catch {
                await MainActor.run {
                    isBlockingTime = false
                    blockTimeMessage = error.localizedDescription
                    showBlockTimeError = true
                }
            }
        }
    }

    // MARK: - Calendar Access
    private func requestCalendarAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                print("❌ Calendar access error: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Create Calendar Event
    private func createCalendarEvent(title: String, startDate: Date, endDate: Date, notes: String?) async throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Add an alert 15 minutes before
        let alarm = EKAlarm(relativeOffset: -15 * 60)
        event.addAlarm(alarm)

        try eventStore.save(event, span: .thisEvent)
        print("✅ Created calendar event: \(title) from \(startDate) to \(endDate)")

        // Notify TodayView to refresh calendar
        await MainActor.run {
            NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: nil)
        }
    }

    // MARK: - Parse Time from Label
    private func parseTimeFromLabel(_ label: String?) -> Date? {
        guard let label = label else { return nil }

        let calendar = Calendar.current
        let today = Date()

        // Try common time formats like "10:00 AM", "2:30 PM", "10:00", "14:30"
        let formatters: [DateFormatter] = {
            let f1 = DateFormatter()
            f1.dateFormat = "h:mm a"  // 10:00 AM
            let f2 = DateFormatter()
            f2.dateFormat = "HH:mm"   // 14:30
            let f3 = DateFormatter()
            f3.dateFormat = "h a"     // 10 AM
            return [f1, f2, f3]
        }()

        // Extract just the time part (handle labels like "Best at 10:00 AM" or "10:00 AM - 11:00 AM")
        let timePatterns = [
            #"(\d{1,2}:\d{2}\s*(?:AM|PM|am|pm))"#,  // 10:00 AM
            #"(\d{1,2}\s*(?:AM|PM|am|pm))"#,         // 10 AM
            #"(\d{1,2}:\d{2})"#                       // 10:00
        ]

        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: label, options: [], range: NSRange(label.startIndex..., in: label)),
               let range = Range(match.range(at: 1), in: label) {
                let timeString = String(label[range])

                for formatter in formatters {
                    if let parsedTime = formatter.date(from: timeString) {
                        // Combine today's date with parsed time
                        var components = calendar.dateComponents([.year, .month, .day], from: today)
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
                        components.hour = timeComponents.hour
                        components.minute = timeComponents.minute
                        return calendar.date(from: components)
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Add to Reminders
    private func addToReminders() {
        guard !isBlockingTime else { return }

        // Get the due date - try startTime, parse from label, or use fallback
        let dueDate: Date
        if let itemStartTime = item.startTime {
            dueDate = itemStartTime
        } else if let parsedTime = parseTimeFromLabel(item.timeLabel) {
            dueDate = parsedTime
        } else {
            // Fallback: use current time rounded to next 15-minute slot
            let now = Date()
            let calendar = Calendar.current
            let minute = calendar.component(.minute, from: now)
            let roundedMinute = ((minute / 15) + 1) * 15
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            components.minute = roundedMinute % 60
            if roundedMinute >= 60 {
                components.hour = (components.hour ?? 0) + 1
            }
            dueDate = calendar.date(from: components) ?? now
        }

        isBlockingTime = true

        Task {
            do {
                let granted = await requestRemindersAccess()
                guard granted else {
                    await MainActor.run {
                        isBlockingTime = false
                        blockTimeMessage = "Reminders access is required. Please enable it in Settings."
                        showBlockTimeError = true
                    }
                    return
                }

                try await createReminder(
                    title: item.title,
                    dueDate: dueDate,
                    notes: item.description
                )

                await MainActor.run {
                    isBlockingTime = false
                    let formatter = DateFormatter()
                    formatter.timeStyle = .short
                    reminderMessage = "'\(item.title)' has been added to your Reminders for \(formatter.string(from: dueDate))."
                    showReminderSuccess = true
                }
            } catch {
                await MainActor.run {
                    isBlockingTime = false
                    blockTimeMessage = error.localizedDescription
                    showBlockTimeError = true
                }
            }
        }
    }

    // MARK: - Reminders Access
    private func requestRemindersAccess() async -> Bool {
        if #available(iOS 17.0, *) {
            do {
                return try await eventStore.requestFullAccessToReminders()
            } catch {
                print("❌ Reminders access error: \(error)")
                return false
            }
        } else {
            return await withCheckedContinuation { continuation in
                eventStore.requestAccess(to: .reminder) { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Create Reminder
    private func createReminder(title: String, dueDate: Date, notes: String?) async throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.notes = notes

        // Set the due date with alarm
        let calendar = Calendar.current
        let dueDateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.dueDateComponents = dueDateComponents

        // Add an alarm at the due time
        let alarm = EKAlarm(absoluteDate: dueDate)
        reminder.addAlarm(alarm)

        // Use default reminders list
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        try eventStore.save(reminder, commit: true)
        print("✅ Created reminder: \(title) due at \(dueDate)")
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(text)
                .font(DesignSystem.Typography.caption2)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

// MARK: - Quick Add Input
struct QuickAddInputView: View {
    @Binding var text: String
    @Binding var deadline: Date?
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSubmit: () -> Void

    @State private var showDatePicker = false

    private var deadlineLabel: String? {
        guard let deadline = deadline else { return nil }
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(deadline) {
            formatter.dateFormat = "h:mm a"
            return "Today \(formatter.string(from: deadline))"
        } else if Calendar.current.isDateInTomorrow(deadline) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow \(formatter.string(from: deadline))"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            return formatter.string(from: deadline)
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
                    .font(.system(size: 20))

                TextField("Add a task...", text: $text)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .focused(isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        onSubmit()
                    }

                // Clock button to set deadline
                Button {
                    showDatePicker = true
                } label: {
                    Image(systemName: deadline != nil ? "clock.fill" : "clock")
                        .foregroundColor(deadline != nil ? DesignSystem.Colors.primary : DesignSystem.Colors.tertiaryText)
                        .font(.system(size: 18))
                }

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !text.isEmpty {
                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                            .font(.system(size: 24))
                    }
                }
            }

            // Show selected deadline
            if let label = deadlineLabel {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.primary)

                    Text(label)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Button {
                        deadline = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    Spacer()
                }
                .padding(.leading, 28)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.tertiaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .sheet(isPresented: $showDatePicker) {
            QuickAddDatePickerSheet(deadline: $deadline, isPresented: $showDatePicker)
        }
    }
}

// MARK: - Date Picker Sheet
struct QuickAddDatePickerSheet: View {
    @Binding var deadline: Date?
    @Binding var isPresented: Bool
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Quick options
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Quick Options")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        QuickDateButton(title: "Today EOD", systemImage: "sun.max") {
                            selectedDate = endOfDay(Date())
                        }
                        QuickDateButton(title: "Tomorrow", systemImage: "sunrise") {
                            selectedDate = endOfDay(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                        }
                        QuickDateButton(title: "Next Week", systemImage: "calendar") {
                            selectedDate = endOfDay(Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date())
                        }
                    }
                }
                .padding(.horizontal)

                Divider()

                // Date and time picker
                DatePicker(
                    "Deadline",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Set Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        deadline = selectedDate
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            if let existingDeadline = deadline {
                selectedDate = existingDeadline
            }
        }
    }

    private func endOfDay(_ date: Date) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 23
        components.minute = 59
        return calendar.date(from: components) ?? date
    }
}

// MARK: - Quick Date Button
struct QuickDateButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.secondaryBackground)
            .foregroundColor(DesignSystem.Colors.primaryText)
            .cornerRadius(DesignSystem.CornerRadius.sm)
        }
    }
}

// MARK: - Task Row (Legacy)
struct TaskRowView: View {
    let task: UserTask
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Checkbox
            Button(action: onComplete) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.isComplete ? DesignSystem.Colors.success : DesignSystem.Colors.tertiaryText)
            }

            // Task content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(task.title)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(task.isComplete ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                        .strikethrough(task.isComplete)

                    if task.isReminder == true {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.warning)
                    }

                    if task.priority == .urgent || task.priority == .high {
                        Image(systemName: task.priority?.icon ?? "exclamationmark")
                            .font(.system(size: 10))
                            .foregroundColor(task.priorityColor)
                    }
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    if let timeLabel = task.displayTimeLabel {
                        HStack(spacing: 2) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(timeLabel)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    HStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text(task.displayDuration)
                            .font(DesignSystem.Typography.caption)
                    }
                    .foregroundColor(DesignSystem.Colors.tertiaryText)

                    if task.isOverdue == true {
                        Text("Pending")
                            .font(DesignSystem.Typography.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }

            Spacer()

            Menu {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .padding(8)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.secondaryBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Empty Up Next View
struct EmptyUpNextView: View {
    let message: String?

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 32))
                .foregroundColor(DesignSystem.Colors.success.opacity(0.5))

            Text(message ?? "All caught up!")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text("Add a task or check your calendar")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        DesignSystem.Colors.background.ignoresSafeArea()

        ScrollView {
            UpNextSectionView()
                .padding()
        }
    }
    .preferredColorScheme(.dark)
}
