import SwiftUI

/// Sheet for adding new tasks
struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var dueDate: Date = Date()
    @State private var hasDueDate = false
    @State private var hasDeadline = false
    @State private var deadlineTime: Date = Date()
    @State private var priority: TaskPriority = .medium
    @State private var estimatedMinutes: Int = 30
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var hasReminder = false
    @State private var reminderMinutesBefore: Int = 15

    enum ReminderTiming: Int, CaseIterable {
        case atTime = 0
        case fiveMinutes = 5
        case fifteenMinutes = 15
        case thirtyMinutes = 30
        case oneHour = 60
        case twoHours = 120

        var displayName: String {
            switch self {
            case .atTime: return "At deadline"
            case .fiveMinutes: return "5 min before"
            case .fifteenMinutes: return "15 min before"
            case .thirtyMinutes: return "30 min before"
            case .oneHour: return "1 hour before"
            case .twoHours: return "2 hours before"
            }
        }
    }

    enum TaskPriority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"

        var color: Color {
            switch self {
            case .low: return DesignSystem.Colors.tertiaryText
            case .medium: return DesignSystem.Colors.primary
            case .high: return DesignSystem.Colors.warningYellow
            case .urgent: return DesignSystem.Colors.errorRed
            }
        }

        var icon: String {
            switch self {
            case .low: return "flag"
            case .medium: return "flag.fill"
            case .high: return "flag.fill"
            case .urgent: return "exclamationmark.triangle.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Title Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Task")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextField("What do you need to do?", text: $title)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Priority Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Priority")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        Button(action: { priority = p }) {
                                            HStack(spacing: DesignSystem.Spacing.xs) {
                                                Image(systemName: p.icon)
                                                    .font(.caption)
                                                Text(p.rawValue)
                                                    .font(.caption.weight(.medium))
                                            }
                                            .foregroundColor(priority == p ? .white : p.color)
                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                            .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                            .background(
                                                Capsule()
                                                    .fill(priority == p ? p.color : p.color.opacity(0.15))
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        // Due Date Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasDueDate) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "calendar")
                                            .foregroundColor(DesignSystem.Colors.primary)
                                        Text("Due Date")
                                            .font(.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                }
                                .toggleStyle(.switch)

                                if hasDueDate {
                                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                                        .datePickerStyle(.graphical)
                                        .padding(.top, DesignSystem.Spacing.sm)
                                }
                            }
                        }

                        // Deadline Time Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Toggle(isOn: $hasDeadline) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(DesignSystem.Colors.errorRed)
                                        Text("Must finish by")
                                            .font(.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                }
                                .toggleStyle(.switch)

                                if hasDeadline {
                                    DatePicker("Deadline", selection: $deadlineTime, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .padding(.top, DesignSystem.Spacing.xs)
                                }
                            }
                        }

                        // Reminder Notification Card (only show if deadline is set)
                        if hasDeadline {
                            formCard {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                    Toggle(isOn: $hasReminder) {
                                        HStack(spacing: DesignSystem.Spacing.sm) {
                                            Image(systemName: "bell.fill")
                                                .foregroundColor(DesignSystem.Colors.claraPurple)
                                            Text("Remind Me")
                                                .font(.subheadline)
                                                .foregroundColor(DesignSystem.Colors.primaryText)
                                        }
                                    }
                                    .toggleStyle(.switch)

                                    if hasReminder {
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: DesignSystem.Spacing.sm) {
                                                ForEach(ReminderTiming.allCases, id: \.rawValue) { timing in
                                                    Button(action: { reminderMinutesBefore = timing.rawValue }) {
                                                        Text(timing.displayName)
                                                            .font(.caption.weight(.medium))
                                                            .foregroundColor(reminderMinutesBefore == timing.rawValue ? .white : DesignSystem.Colors.primaryText)
                                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                                            .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                                            .background(
                                                                Capsule()
                                                                    .fill(reminderMinutesBefore == timing.rawValue ? DesignSystem.Colors.claraPurple : DesignSystem.Colors.claraPurple.opacity(0.15))
                                                            )
                                                    }
                                                }
                                            }
                                        }
                                        .padding(.top, DesignSystem.Spacing.xs)
                                    }
                                }
                            }
                        }

                        // Estimated Time Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "hourglass")
                                        .foregroundColor(DesignSystem.Colors.claraPurple)
                                    Text("Estimated Time")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                    Spacer()
                                    Text("\(estimatedMinutes) min")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(DesignSystem.Colors.primary)
                                }

                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach([15, 30, 45, 60, 90, 120], id: \.self) { mins in
                                        Button(action: { estimatedMinutes = mins }) {
                                            Text(mins < 60 ? "\(mins)m" : "\(mins/60)h")
                                                .font(.caption.weight(.medium))
                                                .foregroundColor(estimatedMinutes == mins ? .white : DesignSystem.Colors.primaryText)
                                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                                .padding(.vertical, DesignSystem.Spacing.xs + 2)
                                                .background(
                                                    Capsule()
                                                        .fill(estimatedMinutes == mins ? DesignSystem.Colors.claraPurple : DesignSystem.Colors.claraPurple.opacity(0.15))
                                                )
                                        }
                                    }
                                }
                            }
                        }

                        // Notes Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Notes")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextEditor(text: $notes)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .frame(minHeight: 80)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Save Button
                        Button(action: saveTask) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                                Text(isSaving ? "Saving..." : "Add Task")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.successGradient)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .shadow(color: DesignSystem.Colors.successGreen.opacity(0.4), radius: 12, y: 6)
                        }
                        .disabled(title.isEmpty || isSaving)
                        .opacity(title.isEmpty ? 0.6 : 1.0)
                        .padding(.horizontal, DesignSystem.Spacing.md)

                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }

                        Spacer(minLength: 50)
                    }
                    .padding(DesignSystem.Spacing.md)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func saveTask() {
        guard !title.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let deadlineType: String?
                if hasDeadline {
                    deadlineType = "SPECIFIC_TIME"
                } else if hasDueDate {
                    deadlineType = "END_OF_DAY"
                } else {
                    deadlineType = "NO_DEADLINE"
                }

                let effectiveDeadline: Date?
                if hasDeadline {
                    effectiveDeadline = deadlineTime
                } else if hasDueDate {
                    effectiveDeadline = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: dueDate)
                } else {
                    effectiveDeadline = nil
                }

                let taskRequest = TaskRequest(
                    title: title,
                    description: notes.isEmpty ? nil : notes,
                    durationMinutes: estimatedMinutes,
                    preferredTimeSlot: nil,
                    preferredTime: nil,
                    targetDate: hasDueDate ? dueDate : Date(),
                    deadline: effectiveDeadline,
                    deadlineType: deadlineType,
                    notifyMinutesBefore: (hasDeadline && hasReminder) ? reminderMinutesBefore : nil,
                    isReminder: nil,
                    reminderTime: nil,
                    syncToReminders: nil,
                    priority: priority.rawValue.uppercased(),
                    category: nil,
                    tags: nil,
                    source: "ios_fab"
                )

                let _ = try await APIService.shared.createTask(taskRequest)

                await MainActor.run {
                    isSaving = false
                    NotificationCenter.default.post(name: NSNotification.Name("TaskCreated"), object: nil)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "Failed to save task: \(error.localizedDescription)"
                    print("❌ Failed to create task: \(error)")
                }
            }
        }
    }
}
