import SwiftUI

/// Weekend Quick Pick - Let users choose activities for today from their saved interests
struct WeekendQuickPickView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: WeekendQuickPickViewModel

    let onPlanGenerated: (WeekendPlanResponse) -> Void

    init(onPlanGenerated: @escaping (WeekendPlanResponse) -> Void) {
        self._viewModel = StateObject(wrappedValue: WeekendQuickPickViewModel())
        self.onPlanGenerated = onPlanGenerated
    }

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerSection

                        if viewModel.isLoading {
                            loadingView
                        } else if viewModel.userInterests == nil {
                            noInterestsView
                        } else {
                            // Mood Selection
                            moodSection

                            // Quick Pick Interests
                            if !viewModel.availableActivities.isEmpty {
                                quickPickSection(
                                    title: "Activities",
                                    subtitle: "What sounds good today?",
                                    icon: "figure.run",
                                    color: DesignSystem.Colors.emerald,
                                    options: viewModel.availableActivities,
                                    selected: $viewModel.selectedActivities
                                )
                            }

                            if !viewModel.availableLifestyle.isEmpty {
                                quickPickSection(
                                    title: "Lifestyle",
                                    subtitle: "How do you want to spend time?",
                                    icon: "book.fill",
                                    color: DesignSystem.Colors.violet,
                                    options: viewModel.availableLifestyle,
                                    selected: $viewModel.selectedLifestyle
                                )
                            }

                            if !viewModel.availableSocial.isEmpty {
                                quickPickSection(
                                    title: "Social",
                                    subtitle: "Who are you with today?",
                                    icon: "person.3.fill",
                                    color: DesignSystem.Colors.amber,
                                    options: viewModel.availableSocial,
                                    selected: $viewModel.selectedSocial
                                )
                            }

                            // Preferences
                            preferencesSection

                            // Generate Button
                            generateButton
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Plan Your Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong")
            }
            .onAppear {
                viewModel.loadUserInterests()
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "EC4899"), DesignSystem.Colors.violet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            Text("What's on your mind today?")
                .font(.title2.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Pick a few activities and we'll create a personalized plan for you")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Mood Section
    private var moodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How are you feeling?")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            HStack(spacing: 12) {
                ForEach(WeekendMood.allCases, id: \.self) { mood in
                    MoodChip(
                        mood: mood,
                        isSelected: viewModel.selectedMood == mood,
                        onTap: { viewModel.selectedMood = mood }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Quick Pick Section
    private func quickPickSection(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        options: [InterestOption],
        selected: Binding<Set<String>>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundColor(color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                Spacer()
                if !selected.wrappedValue.isEmpty {
                    Text("\(selected.wrappedValue.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(color))
                }
            }

            FlowLayout(spacing: 8) {
                ForEach(options) { option in
                    QuickPickChip(
                        option: option,
                        isSelected: selected.wrappedValue.contains(option.id),
                        color: color,
                        onTap: {
                            if selected.wrappedValue.contains(option.id) {
                                selected.wrappedValue.remove(option.id)
                            } else {
                                selected.wrappedValue.insert(option.id)
                            }
                        }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Preferences Section
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Pace")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Picker("Pace", selection: $viewModel.selectedPace) {
                    Text("Chill").tag("relaxed")
                    Text("Balanced").tag("balanced")
                    Text("Active").tag("active")
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("How far will you go?")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Picker("Distance", selection: $viewModel.selectedDistance) {
                    Text("Nearby").tag("nearby")
                    Text("Moderate").tag("moderate")
                    Text("Road Trip").tag("willing_to_travel")
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Generate Button
    private var generateButton: some View {
        Button(action: {
            Task {
                if let plan = await viewModel.generatePlan() {
                    onPlanGenerated(plan)
                    dismiss()
                }
            }
        }) {
            HStack {
                if viewModel.isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "wand.and.stars")
                    Text("Generate My Day")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(viewModel.hasAnySelection
                        ? LinearGradient(
                            colors: [Color(hex: "EC4899"), DesignSystem.Colors.violet],
                            startPoint: .leading,
                            endPoint: .trailing
                          )
                        : LinearGradient(colors: [Color.gray], startPoint: .leading, endPoint: .trailing)
                    )
            )
        }
        .disabled(!viewModel.hasAnySelection || viewModel.isGenerating)
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading your interests...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - No Interests View
    private var noInterestsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text("No interests set up yet")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Set up your interests in Settings to get personalized weekend plans")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button("Set Up Interests") {
                dismiss()
                // Navigate to interests setup
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Capsule().fill(DesignSystem.Colors.primary))
        }
        .padding()
    }
}

// MARK: - Mood Enum
enum WeekendMood: String, CaseIterable {
    case energetic = "energetic"
    case relaxed = "relaxed"
    case social = "social"
    case adventurous = "adventurous"

    var icon: String {
        switch self {
        case .energetic: return "bolt.fill"
        case .relaxed: return "leaf.fill"
        case .social: return "person.2.fill"
        case .adventurous: return "map.fill"
        }
    }

    var label: String {
        switch self {
        case .energetic: return "Energetic"
        case .relaxed: return "Relaxed"
        case .social: return "Social"
        case .adventurous: return "Adventurous"
        }
    }

    var color: Color {
        switch self {
        case .energetic: return DesignSystem.Colors.amber
        case .relaxed: return DesignSystem.Colors.emerald
        case .social: return Color(hex: "EC4899")
        case .adventurous: return DesignSystem.Colors.blue
        }
    }
}

// MARK: - Mood Chip
struct MoodChip: View {
    let mood: WeekendMood
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: mood.icon)
                    .font(.system(size: 20))
                Text(mood.label)
                    .font(.caption.weight(.medium))
            }
            .foregroundColor(isSelected ? .white : mood.color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? mood.color : mood.color.opacity(0.15))
            )
        }
    }
}

// MARK: - Quick Pick Chip
struct QuickPickChip: View {
    let option: InterestOption
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 14))
                Text(option.name)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : DesignSystem.Colors.cardBackground)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
    }
}

// MARK: - Weekend Plan Result View
struct WeekendPlanResultView: View {
    let plan: WeekendPlanResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header with celebration
                        headerSection

                        // Summary
                        if let summary = plan.summary {
                            summaryCard(summary)
                        }

                        // Activities Timeline
                        if let activities = plan.activities, !activities.isEmpty {
                            activitiesSection(activities)
                        }

                        // Stats Row
                        statsRow

                        // Tips Section
                        if let tips = plan.tips, !tips.isEmpty {
                            tipsSection(tips)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
            }
            .navigationTitle("Your Day Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: "EC4899"), DesignSystem.Colors.violet],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            Text("Your Day is Planned!")
                .font(.title2.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            if let date = plan.date {
                Text(formatDate(date))
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
    }

    // MARK: - Summary Card
    private func summaryCard(_ summary: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(DesignSystem.Colors.violet)
                Text("Overview")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Text(summary)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Activities Section
    private func activitiesSection(_ activities: [PlannedActivity]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundColor(DesignSystem.Colors.emerald)
                Text("Your Activities")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                Text("\(activities.count) planned")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(.horizontal)

            VStack(spacing: 0) {
                ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                    ActivityTimelineRow(activity: activity, isLast: index == activities.count - 1)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 16) {
            if let duration = plan.totalDuration {
                PlanStatBadge(
                    icon: "clock.fill",
                    value: formatDuration(duration),
                    label: "Duration",
                    color: DesignSystem.Colors.blue
                )
            }

            if let budget = plan.estimatedBudget {
                PlanStatBadge(
                    icon: "dollarsign.circle.fill",
                    value: budget,
                    label: "Budget",
                    color: DesignSystem.Colors.emerald
                )
            }

            if let activities = plan.activities {
                PlanStatBadge(
                    icon: "checkmark.circle.fill",
                    value: "\(activities.count)",
                    label: "Activities",
                    color: DesignSystem.Colors.violet
                )
            }
        }
    }

    // MARK: - Tips Section
    private func tipsSection(_ tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(DesignSystem.Colors.amber)
                Text("Pro Tips")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.amber)
                            .padding(.top, 2)

                        Text(tip)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    // MARK: - Helpers
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
        return dateString
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Activity Timeline Row
struct ActivityTimelineRow: View {
    let activity: PlannedActivity
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timeline indicator
            VStack(spacing: 0) {
                Circle()
                    .fill(categoryColor)
                    .frame(width: 12, height: 12)

                if !isLast {
                    Rectangle()
                        .fill(categoryColor.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            // Activity content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(activity.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    if let time = activity.startTime {
                        Text(time)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                if let description = activity.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let duration = activity.duration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text("\(duration)m")
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    if let location = activity.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                            Text(location)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }

    private var categoryColor: Color {
        switch activity.category?.lowercased() {
        case "fitness", "exercise", "outdoor":
            return DesignSystem.Colors.emerald
        case "food", "dining":
            return DesignSystem.Colors.amber
        case "entertainment", "culture":
            return DesignSystem.Colors.violet
        case "social":
            return Color(hex: "EC4899")
        case "relaxation", "wellness":
            return DesignSystem.Colors.blue
        default:
            return DesignSystem.Colors.primary
        }
    }
}

// MARK: - Plan Stat Badge
struct PlanStatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Preview
#Preview {
    WeekendQuickPickView { plan in
        print("Plan generated: \(plan)")
    }
}
