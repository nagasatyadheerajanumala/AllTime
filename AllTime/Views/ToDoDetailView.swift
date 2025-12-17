import SwiftUI
import Combine

// MARK: - ToDo Detail View
struct ToDoDetailView: View {
    let todoTile: TodoTileData?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ToDoDetailViewModel()
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .all

    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case pending = "Open"
        case overdue = "Catch Up"
        case completed = "Done"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats header
                statsHeader
                    .padding(.horizontal)
                    .padding(.top, 16)

                // Filter tabs
                filterTabs
                    .padding(.vertical, 12)

                // Tasks list
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    loadingState
                } else if filteredTasks.isEmpty {
                    emptyState
                } else {
                    tasksList
                }
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("To-Do")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(onTaskAdded: {
                    Task { await viewModel.loadTasks() }
                })
            }
            .task {
                await viewModel.loadTasks()
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var filteredTasks: [UserTask] {
        switch selectedFilter {
        case .all:
            return viewModel.tasks
        case .pending:
            return viewModel.tasks.filter { $0.status != .completed && !($0.isOverdue ?? false) }
        case .overdue:
            return viewModel.tasks.filter { $0.isOverdue ?? false }
        case .completed:
            return viewModel.tasks.filter { $0.status == .completed }
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: 12) {
            TaskStatCard(
                value: "\(todoTile?.pendingCount ?? viewModel.pendingCount)",
                label: "Open",
                color: DesignSystem.Colors.primary
            )
            TaskStatCard(
                value: "\(todoTile?.overdueCount ?? viewModel.overdueCount)",
                label: "Catch Up",
                color: Color(hex: "FF9500")
            )
            TaskStatCard(
                value: "\(todoTile?.completedTodayCount ?? viewModel.completedCount)",
                label: "Done",
                color: Color(hex: "10B981")
            )
        }
    }

    // MARK: - Filter Tabs
    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    FilterTab(
                        title: filter.rawValue,
                        count: countForFilter(filter),
                        isSelected: selectedFilter == filter,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedFilter = filter
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private func countForFilter(_ filter: TaskFilter) -> Int {
        switch filter {
        case .all: return viewModel.tasks.count
        case .pending: return viewModel.tasks.filter { $0.status != .completed && !($0.isOverdue ?? false) }.count
        case .overdue: return viewModel.tasks.filter { $0.isOverdue ?? false }.count
        case .completed: return viewModel.tasks.filter { $0.status == .completed }.count
        }
    }

    // MARK: - Tasks List
    private var tasksList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredTasks, id: \.id) { task in
                    TodoTaskRow(
                        task: task,
                        onToggle: {
                            Task { await viewModel.toggleTask(task) }
                        },
                        onDelete: {
                            Task { await viewModel.deleteTask(task) }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Loading State
    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
            Text("Loading tasks...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: selectedFilter == .completed ? "checkmark.circle.fill" : "checklist")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            if selectedFilter == .all || selectedFilter == .pending {
                Button(action: { showingAddTask = true }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Task")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary)
                    )
                }
            }
            Spacer()
        }
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "No tasks yet"
        case .pending: return "Nothing open"
        case .overdue: return "All caught up"
        case .completed: return "Nothing done yet"
        }
    }
}

// MARK: - Task Stat Card
struct TaskStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.bold))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Filter Tab
struct FilterTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.3) : DesignSystem.Colors.cardBackground)
                        )
                }
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.cardBackground)
            )
        }
    }
}

// MARK: - Todo Task Row
struct TodoTaskRow: View {
    let task: UserTask
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isDeleting = false

    private var isCompleted: Bool {
        task.status == .completed
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(checkboxColor, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isCompleted {
                        Circle()
                            .fill(Color(hex: "10B981"))
                            .frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }

            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundColor(isCompleted ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                    .strikethrough(isCompleted)

                HStack(spacing: 8) {
                    if let priority = task.priority {
                        TaskPriorityBadge(priority: priority)
                    }

                    if let time = task.timeLabel {
                        Text(time)
                            .font(.caption)
                            .foregroundColor(task.isOverdue == true ? Color(hex: "FF9500") : DesignSystem.Colors.secondaryText)
                    }

                    if task.isOverdue == true {
                        Text("Past")
                            .font(.caption)
                            .foregroundColor(Color(hex: "FF9500"))
                    }
                }
            }

            Spacer()

            // Delete button
            Button(action: {
                withAnimation {
                    isDeleting = true
                }
                onDelete()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .opacity(isDeleting ? 0.5 : 1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(task.isOverdue == true ? Color(hex: "FF9500").opacity(0.08) : DesignSystem.Colors.cardBackground)
        )
    }

    private var checkboxColor: Color {
        if isCompleted {
            return Color(hex: "10B981")
        }
        if task.isOverdue == true {
            return Color(hex: "FF9500")
        }
        switch task.priority {
        case .urgent: return Color(hex: "FF9500")
        case .high: return Color(hex: "5856D6")
        default: return DesignSystem.Colors.secondaryText
        }
    }
}

// MARK: - Task Priority Badge
struct TaskPriorityBadge: View {
    let priority: TaskPriority

    var body: some View {
        Text(priority.displayName)
            .font(.caption2.weight(.medium))
            .foregroundColor(priorityColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(priorityColor.opacity(0.15))
            )
    }

    private var priorityColor: Color {
        switch priority {
        case .urgent: return Color(hex: "FF9500")   // Orange - time-sensitive
        case .high: return Color(hex: "5856D6")     // Indigo - important
        case .medium: return Color(hex: "007AFF")   // Blue - regular
        case .low: return DesignSystem.Colors.secondaryText
        }
    }
}

// MARK: - Add Task View
struct AddTaskView: View {
    let onTaskAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var priority = "MEDIUM"
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let priorities = ["LOW", "MEDIUM", "HIGH", "URGENT"]

    var body: some View {
        NavigationView {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.self) { p in
                            Text(p.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Due Date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
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
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(title.isEmpty || isSubmitting)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func addTask() {
        guard !title.isEmpty else { return }
        isSubmitting = true

        Task {
            do {
                let taskRequest = TaskRequest(
                    title: title,
                    description: nil,
                    durationMinutes: nil,
                    preferredTimeSlot: nil,
                    preferredTime: nil,
                    targetDate: hasDueDate ? dueDate : nil,
                    deadline: hasDueDate ? dueDate : nil,
                    deadlineType: hasDueDate ? "SPECIFIC_TIME" : "NO_DEADLINE",
                    notifyMinutesBefore: nil,
                    isReminder: false,
                    reminderTime: nil,
                    syncToReminders: false,
                    priority: priority,
                    category: nil,
                    tags: nil,
                    source: "ios_app"
                )

                let _ = try await APIService.shared.createTask(taskRequest)

                await MainActor.run {
                    isSubmitting = false
                    onTaskAdded()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    print("❌ Failed to create task: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - ToDo Detail ViewModel
@MainActor
class ToDoDetailViewModel: ObservableObject {
    @Published var tasks: [UserTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    var pendingCount: Int {
        tasks.filter { $0.status != .completed }.count
    }

    var overdueCount: Int {
        tasks.filter { $0.isOverdue ?? false }.count
    }

    var completedCount: Int {
        tasks.filter { $0.status == .completed }.count
    }

    func loadTasks() async {
        isLoading = true
        do {
            tasks = try await APIService.shared.fetchTodaysTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func toggleTask(_ task: UserTask) async {
        guard let taskId = task.id else { return }
        let newStatus: TaskStatus = task.status == .completed ? .pending : .completed
        do {
            _ = try await APIService.shared.updateTaskStatus(taskId: Int(taskId), status: newStatus.rawValue)
            await loadTasks()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTask(_ task: UserTask) async {
        guard let taskId = task.id else { return }
        do {
            try await APIService.shared.deleteTask(taskId: Int(taskId))
            tasks.removeAll { $0.id == task.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


// MARK: - Preview
#Preview {
    ToDoDetailView(
        todoTile: TodoTileData(
            previewLine: "Review PR comments",
            pendingCount: 3,
            overdueCount: 1,
            completedTodayCount: 2,
            topTasks: nil
        )
    )
}
