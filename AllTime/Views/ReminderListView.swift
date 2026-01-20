import SwiftUI

struct ReminderListView: View {
    @StateObject private var viewModel = ReminderViewModel()
    @State private var showingCreateReminder = false
    @State private var selectedReminder: Reminder?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background - using DesignSystem for consistency
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.reminders.isEmpty {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    ReminderErrorView(message: error) {
                        Task {
                            await viewModel.loadReminders()
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Status filter
                            StatusFilterView(selectedStatus: $viewModel.selectedStatus) { status in
                                Task {
                                    await viewModel.loadReminders(status: status)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            // "Do this first" card - opinionated prioritization
                            if let doFirst = viewModel.doThisFirst {
                                DoThisFirstCard(
                                    recommendation: doFirst,
                                    onTap: {
                                        selectedReminder = doFirst.reminder
                                        showingDetail = true
                                    },
                                    onComplete: {
                                        Task {
                                            do {
                                                _ = try await viewModel.completeReminder(id: doFirst.reminder.id)
                                            } catch {
                                                print("Error completing reminder: \(error)")
                                            }
                                        }
                                    }
                                )
                                .padding(.horizontal)
                            }

                            // Grouped reminders
                            let groups = viewModel.groupedReminders()
                            let groupOrder = ["Catch Up", "Today", "Tomorrow", "This Week", "Coming Up"]

                            ForEach(groupOrder, id: \.self) { groupName in
                                if let reminders = groups[groupName], !reminders.isEmpty {
                                    // Filter out the "do this first" reminder from regular groups
                                    let filteredReminders = reminders.filter { reminder in
                                        viewModel.doThisFirst?.reminder.id != reminder.id
                                    }

                                    if !filteredReminders.isEmpty {
                                        ReminderGroupSection(
                                            title: groupName,
                                            reminders: filteredReminders,
                                            onReminderTap: { reminder in
                                                selectedReminder = reminder
                                                showingDetail = true
                                            },
                                            onComplete: { reminder in
                                                Task {
                                                    do {
                                                        _ = try await viewModel.completeReminder(id: reminder.id)
                                                    } catch {
                                                        print("Error completing reminder: \(error)")
                                                    }
                                                }
                                            },
                                            onSnooze: { reminder in
                                                Task {
                                                    do {
                                                        let snoozeDate = Date().addingTimeInterval(30 * 60) // 30 minutes
                                                        _ = try await viewModel.snoozeReminder(id: reminder.id, until: snoozeDate)
                                                    } catch {
                                                        print("Error snoozing reminder: \(error)")
                                                    }
                                                }
                                            },
                                            onDelete: { reminder in
                                                Task {
                                                    do {
                                                        try await viewModel.deleteReminder(id: reminder.id)
                                                    } catch {
                                                        print("Error deleting reminder: \(error)")
                                                    }
                                                }
                                            }
                                        )
                                    }
                                }
                            }

                            if groups.isEmpty && viewModel.doThisFirst == nil {
                                EmptyRemindersView()
                                    .padding(.top, 50)
                            }
                        }
                        .padding(.vertical)
                        .padding(.bottom, 100) // Space for tab bar
                    }
                }
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateReminder = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateReminder) {
                CreateReminderView(viewModel: viewModel)
            }
            .sheet(item: $selectedReminder) { reminder in
                ReminderDetailView(reminder: reminder, viewModel: viewModel)
            }
            .refreshable {
                await viewModel.loadReminders()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshReminders"))) { _ in
                Task {
                    await viewModel.loadReminders()
                }
            }
            .onAppear {
                Task {
                    // Request EventKit permission if needed
                    let eventKitManager = EventKitReminderManager.shared
                    if !eventKitManager.isAuthorized {
                        let granted = await eventKitManager.requestAuthorization()
                        if granted {
                            print("✅ ReminderListView: EventKit permission granted")
                        } else {
                            print("⚠️ ReminderListView: EventKit permission denied")
                        }
                    }

                    // Fetch reminders and prioritization in parallel
                    async let remindersTask: () = viewModel.loadReminders()
                    async let prioritizationTask: () = viewModel.loadPrioritizedReminders()
                    _ = await (remindersTask, prioritizationTask)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenReminder"))) { notification in
                if let reminderId = notification.userInfo?["reminderId"] as? Int64 {
                    Task {
                        do {
                            let reminder = try await viewModel.getReminder(id: reminderId)
                            selectedReminder = reminder
                            showingDetail = true
                        } catch {
                            print("Error loading reminder: \(error)")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Status Filter View

struct StatusFilterView: View {
    @Binding var selectedStatus: ReminderStatus?
    let onStatusChange: (ReminderStatus?) -> Void

    var body: some View {
        HStack(spacing: 8) {
            FilterChip(
                title: "All",
                isSelected: selectedStatus == nil,
                action: {
                    selectedStatus = nil
                    onStatusChange(nil)
                }
            )

            ForEach(ReminderStatus.allCases, id: \.self) { status in
                FilterChip(
                    title: status.displayName,
                    isSelected: selectedStatus == status,
                    action: {
                        selectedStatus = status
                        onStatusChange(status)
                    }
                )
            }
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .fontWeight(isSelected ? .semibold : .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBackground)
                )
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryText)
        }
    }
}

// MARK: - Reminder Group Section

struct ReminderGroupSection: View {
    let title: String
    let reminders: [Reminder]
    let onReminderTap: (Reminder) -> Void
    let onComplete: (Reminder) -> Void
    let onSnooze: (Reminder) -> Void
    var onDelete: ((Reminder) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .padding(.horizontal, DesignSystem.Spacing.md)

            ForEach(reminders) { reminder in
                ReminderRowView(
                    reminder: reminder,
                    onComplete: { onComplete(reminder) },
                    onSnooze: { onSnooze(reminder) },
                    onDelete: onDelete != nil ? { onDelete?(reminder) } : nil
                )
                .padding(.horizontal, DesignSystem.Spacing.md)
                .onTapGesture {
                    onReminderTap(reminder)
                }
            }
        }
    }
}

// MARK: - Empty Reminders View

struct EmptyRemindersView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("All Clear")
                .font(.title2.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Tap + to jot something down")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }
}

// MARK: - Reminder Error View

struct ReminderErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("Couldn't load")
                .font(.title2.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Check your connection and try again")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: onRetry) {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary)
                    )
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - Do This First Card

struct DoThisFirstCard: View {
    let recommendation: DoThisFirstRecommendation
    let onTap: () -> Void
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)

                Text("Do this first")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)

                Spacer()
            }

            // Task content
            Button(action: {
                HapticManager.shared.lightTap()
                onTap()
            }) {
                HStack(alignment: .top, spacing: 12) {
                    // Completion button
                    Button(action: {
                        HapticManager.shared.mediumTap()
                        onComplete()
                    }) {
                        Image(systemName: "circle")
                            .font(.system(size: 22))
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(recommendation.reminder.title)
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(2)

                        Text(recommendation.reason)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)

                        // Due date if available
                        if recommendation.reminder.dueDate > Date() {
                            let formatter = RelativeDateTimeFormatter()
                            Text("Due \(formatter.localizedString(for: recommendation.reminder.dueDate, relativeTo: Date()))")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        } else {
                            Text("Overdue")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.primary.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(DesignSystem.Colors.primary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ReminderListView()
}

