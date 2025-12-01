import SwiftUI

struct ReminderListView: View {
    @StateObject private var viewModel = ReminderViewModel()
    @State private var showingCreateReminder = false
    @State private var selectedReminder: Reminder?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.systemGroupedBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.reminders.isEmpty {
                    ProgressView("Loading reminders...")
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
                            
                            // Grouped reminders
                            let groups = viewModel.groupedReminders()
                            let groupOrder = ["Overdue", "Today", "Tomorrow", "This Week", "Later"]
                            
                            ForEach(groupOrder, id: \.self) { groupName in
                                if let reminders = groups[groupName], !reminders.isEmpty {
                                    ReminderGroupSection(
                                        title: groupName,
                                        reminders: reminders,
                                        onReminderTap: { reminder in
                                            selectedReminder = reminder
                                            showingDetail = true
                                        },
                                        onComplete: { reminder in
                                            Task {
                                                try? await viewModel.completeReminder(id: reminder.id)
                                            }
                                        },
                                        onSnooze: { reminder in
                                            Task {
                                                let snoozeDate = Date().addingTimeInterval(30 * 60) // 30 minutes
                                                try? await viewModel.snoozeReminder(id: reminder.id, until: snoozeDate)
                                            }
                                        }
                                    )
                                }
                            }
                            
                            if groups.isEmpty {
                                EmptyRemindersView()
                                    .padding(.top, 50)
                            }
                        }
                        .padding(.vertical)
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
                    
                    await viewModel.loadReminders()
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
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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
            .padding(.horizontal, 4)
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
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color(UIColor.secondarySystemGroupedBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            ForEach(reminders) { reminder in
                ReminderRowView(
                    reminder: reminder,
                    onComplete: { onComplete(reminder) },
                    onSnooze: { onSnooze(reminder) }
                )
                .padding(.horizontal)
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
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Reminders")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a reminder to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Reminder Error View

struct ReminderErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Error")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

#Preview {
    ReminderListView()
}

