import SwiftUI

/// Sheet for adding new reminders
struct AddReminderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var reminderDate: Date = Date()
    @State private var hasTime = true
    @State private var repeatOption: RepeatOption = .never
    @State private var isSaving = false
    @State private var errorMessage: String?

    enum RepeatOption: String, CaseIterable {
        case never = "Never"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var icon: String {
            switch self {
            case .never: return "arrow.right"
            case .daily: return "sun.max.fill"
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar"
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
                                Text("Reminder")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                TextField("What do you want to be reminded of?", text: $title)
                                    .font(.body)
                                    .foregroundColor(DesignSystem.Colors.primaryText)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Date & Time Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(DesignSystem.Colors.warningYellow)
                                    Text("Remind me on")
                                        .font(.subheadline)
                                        .foregroundColor(DesignSystem.Colors.primaryText)
                                }

                                DatePicker("", selection: $reminderDate, displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                                    .datePickerStyle(.graphical)

                                Toggle(isOn: $hasTime) {
                                    HStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: "clock")
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                        Text("Include time")
                                            .font(.subheadline)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                    }
                                }
                                .toggleStyle(.switch)
                            }
                        }

                        // Quick Time Options
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Quick Set")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                                    quickSetButton("In 1 hour", addHours: 1)
                                    quickSetButton("In 3 hours", addHours: 3)
                                    quickSetButton("Tomorrow 9 AM", tomorrow: true)
                                    quickSetButton("This weekend", weekend: true)
                                }
                            }
                        }

                        // Repeat Card
                        formCard {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Repeat")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)

                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(RepeatOption.allCases, id: \.self) { option in
                                        Button(action: { repeatOption = option }) {
                                            VStack(spacing: DesignSystem.Spacing.xs) {
                                                Image(systemName: option.icon)
                                                    .font(.system(size: DesignSystem.Components.iconMedium + 2))
                                                Text(option.rawValue)
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(repeatOption == option ? .white : DesignSystem.Colors.primaryText)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, DesignSystem.Spacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                    .fill(repeatOption == option ? DesignSystem.Colors.warningYellow : DesignSystem.Colors.warningYellow.opacity(0.15))
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
                                    .frame(minHeight: 60)
                                    .padding(DesignSystem.Spacing.sm)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }

                        // Save Button
                        Button(action: saveReminder) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "bell.badge.fill")
                                }
                                Text(isSaving ? "Saving..." : "Set Reminder")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.warningGradient)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .shadow(color: DesignSystem.Colors.warningYellow.opacity(0.4), radius: 12, y: 6)
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
            .navigationTitle("New Reminder")
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

    private func quickSetButton(_ label: String, addHours: Int? = nil, tomorrow: Bool = false, weekend: Bool = false) -> some View {
        Button(action: {
            let calendar = Calendar.current
            if let hours = addHours {
                reminderDate = calendar.date(byAdding: .hour, value: hours, to: Date()) ?? Date()
            } else if tomorrow {
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.day! += 1
                components.hour = 9
                components.minute = 0
                reminderDate = calendar.date(from: components) ?? Date()
            } else if weekend {
                let today = Date()
                let weekday = calendar.component(.weekday, from: today)
                let daysUntilSaturday = (7 - weekday + 7) % 7
                var components = calendar.dateComponents([.year, .month, .day], from: today)
                components.day! += daysUntilSaturday == 0 ? 7 : daysUntilSaturday
                components.hour = 10
                components.minute = 0
                reminderDate = calendar.date(from: components) ?? Date()
            }
            hasTime = true
        }) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(DesignSystem.Colors.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                .stroke(DesignSystem.Colors.calmBorder, lineWidth: 1)
                        )
                )
        }
    }

    private func saveReminder() {
        guard !title.isEmpty else { return }
        isSaving = true
        errorMessage = nil

        Task {
            do {
                let taskRequest = TaskRequest(
                    title: title,
                    description: notes.isEmpty ? nil : notes,
                    durationMinutes: nil,
                    preferredTimeSlot: nil,
                    preferredTime: nil,
                    targetDate: reminderDate,
                    deadline: hasTime ? reminderDate : nil,
                    deadlineType: hasTime ? "SPECIFIC_TIME" : "END_OF_DAY",
                    notifyMinutesBefore: 15,
                    isReminder: true,
                    reminderTime: reminderDate,
                    syncToReminders: true,
                    priority: "MEDIUM",
                    category: nil,
                    tags: nil,
                    source: "ios_fab_reminder"
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
                    errorMessage = "Failed to save reminder: \(error.localizedDescription)"
                    print("❌ Failed to create reminder: \(error)")
                }
            }
        }
    }
}
