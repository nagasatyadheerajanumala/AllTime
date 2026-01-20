import SwiftUI

// MARK: - Classy Daily Summary View

struct DailySummaryView: View {
    @EnvironmentObject var summaryViewModel: DailySummaryViewModel
    @State private var showingDatePicker = false
    @State private var contentOpacity: Double = 0

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Elegant Date Header
                        dateHeader
                            .padding(.top, 8)
                            .padding(.bottom, 32)

                        // Content
                        if summaryViewModel.isLoading && summaryViewModel.summary == nil {
                            ClassyLoadingView()
                                .padding(.top, 80)
                        } else if let summary = summaryViewModel.summary {
                            ClassySummaryContent(
                                summary: summary,
                                parsed: summaryViewModel.parsedSummary,
                                waterGoal: summaryViewModel.waterGoal
                            )
                            .opacity(contentOpacity)
                        } else if let errorMessage = summaryViewModel.errorMessage {
                            ClassyErrorView(message: errorMessage) {
                                Task {
                                    await summaryViewModel.refreshSummary()
                                }
                            }
                            .padding(.top, 80)
                        } else {
                            ClassyEmptyView()
                                .padding(.top, 80)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingDatePicker) {
                ClassyDatePicker(selectedDate: $summaryViewModel.selectedDate)
            }
            .onAppear {
                if summaryViewModel.summary == nil {
                    Task {
                        await summaryViewModel.loadSummary(for: summaryViewModel.selectedDate)
                    }
                }
                withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                    contentOpacity = 1.0
                }
            }
            .onChange(of: summaryViewModel.selectedDate) { oldDate, newDate in
                Task {
                    await summaryViewModel.loadSummary(for: newDate)
                }
            }
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        VStack(spacing: 20) {
            // Title
            Text("Summary")
                .font(.system(size: 34, weight: .light))
                .tracking(2)
                .foregroundColor(.white)

            // Date selector
            Button(action: { showingDatePicker = true }) {
                HStack(spacing: 12) {
                    Text(formattedDate)
                        .font(.system(size: 15, weight: .regular))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.6))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }

            // Refresh indicator
            if summaryViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.blue))
                    .scaleEffect(0.8)
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: summaryViewModel.selectedDate)
    }
}

// MARK: - Classy Summary Content

struct ClassySummaryContent: View {
    let summary: DailySummary
    let parsed: ParsedSummary
    let waterGoal: Double?

    var body: some View {
        VStack(spacing: 32) {
            // Metrics Overview
            if parsed.waterIntake != nil || parsed.steps != nil || parsed.sleepHours != nil {
                ClassyMetricsSection(
                    waterIntake: parsed.waterIntake,
                    waterGoal: waterGoal ?? parsed.waterGoal,
                    steps: parsed.steps,
                    sleepHours: parsed.sleepHours
                )
            }

            // Critical Alerts
            if !parsed.criticalAlerts.isEmpty {
                ClassyAlertsSection(alerts: parsed.criticalAlerts, isCritical: true)
            }

            // Day Overview
            if !summary.daySummary.isEmpty {
                ClassyTextSection(
                    title: "Your Day",
                    icon: "calendar",
                    items: summary.daySummary
                )
            }

            // Health & Recovery
            if !summary.healthSummary.isEmpty {
                ClassyTextSection(
                    title: "Health",
                    icon: "heart",
                    items: summary.healthSummary
                )
            }

            // Suggestions
            if let suggestions = summary.healthBasedSuggestions, !suggestions.isEmpty {
                ClassySuggestionsSection(suggestions: suggestions)
            }

            // Break Schedule
            if let breakRecs = summary.breakRecommendations {
                ClassyBreaksSection(recommendations: breakRecs)
            }

            // Focus
            if !summary.focusRecommendations.isEmpty {
                ClassyTextSection(
                    title: "Focus",
                    icon: "target",
                    items: summary.focusRecommendations
                )
            }

            // Warnings
            if !parsed.warnings.isEmpty {
                ClassyAlertsSection(alerts: parsed.warnings, isCritical: false)
            }
        }
    }
}

// MARK: - Classy Metrics Section

struct ClassyMetricsSection: View {
    let waterIntake: Double?
    let waterGoal: Double?
    let steps: Int?
    let sleepHours: Double?

    var body: some View {
        VStack(spacing: 24) {
            // Section header
            HStack {
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }

            // Metrics grid
            HStack(spacing: 20) {
                if let sleep = sleepHours {
                    ClassyMetricCard(
                        icon: "moon.fill",
                        value: String(format: "%.1f", sleep),
                        unit: "hrs",
                        label: "Sleep",
                        color: Color(hex: "A78BFA")
                    )
                }

                if let steps = steps {
                    ClassyMetricCard(
                        icon: "figure.walk",
                        value: formatSteps(steps),
                        unit: "",
                        label: "Steps",
                        color: Color(hex: "34D399")
                    )
                }

                if let water = waterIntake {
                    ClassyMetricCard(
                        icon: "drop.fill",
                        value: String(format: "%.1f", water),
                        unit: "L",
                        label: "Water",
                        color: DesignSystem.Colors.blue
                    )
                }
            }
        }
    }

    private func formatSteps(_ steps: Int) -> String {
        return steps.formatted()
    }
}

struct ClassyMetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(color)

            // Value
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Label
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .tracking(1)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Classy Text Section

struct ClassyTextSection: View {
    let title: String
    let icon: String
    let items: [String]

    @State private var isExpanded = false
    private let maxCollapsedItems = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(DesignSystem.Colors.blue)

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                if items.count > maxCollapsedItems {
                    Button(action: { withAnimation(.easeInOut(duration: 0.3)) { isExpanded.toggle() } }) {
                        Text(isExpanded ? "Less" : "More")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.blue)
                    }
                }
            }

            // Content
            VStack(alignment: .leading, spacing: 12) {
                let displayItems = isExpanded ? items : Array(items.prefix(maxCollapsedItems))
                ForEach(displayItems, id: \.self) { item in
                    ClassyTextItem(text: cleanText(item))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private func cleanText(_ text: String) -> String {
        var cleaned = text
        // Remove leading bullets/arrows
        if cleaned.hasPrefix("  •") || cleaned.hasPrefix("  →") {
            cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        // Remove leading emojis
        while let first = cleaned.first, first.isEmoji {
            cleaned = String(cleaned.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }
}

struct ClassyTextItem: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(DesignSystem.Colors.blue.opacity(0.5))
                .frame(width: 4, height: 4)
                .padding(.top, 7)

            Text(text)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
        }
    }
}

// MARK: - Classy Suggestions Section

struct ClassySuggestionsSection: View {
    let suggestions: [DailySummarySuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(DesignSystem.Colors.amber)

                Text("Suggestions")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
            }

            // Suggestions
            VStack(spacing: 12) {
                ForEach(suggestions.prefix(4)) { suggestion in
                    ClassySuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

struct ClassySuggestionCard: View {
    let suggestion: DailySummarySuggestion
    @State private var showFoodRecommendations = false
    @State private var showWalkRecommendations = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack {
                // Category icon
                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(categoryColor)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(categoryColor.opacity(0.15))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    if let time = suggestion.suggestedTime {
                        Text(time)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()

                // Priority indicator
                Circle()
                    .fill(priorityColor)
                    .frame(width: 6, height: 6)
            }

            // Description
            Text(suggestion.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.55))
                .lineSpacing(3)

            // Action button
            if let action = suggestion.action {
                Button(action: {
                    print("🔴 Button tapped! Action: '\(action)'")
                    handleAction(action)
                }) {
                    HStack(spacing: 6) {
                        Text(actionLabel(for: action))
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(categoryColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        Capsule()
                            .fill(categoryColor.opacity(0.15))
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showFoodRecommendations) {
            FoodRecommendationsView()
        }
        .sheet(isPresented: $showWalkRecommendations) {
            WalkRecommendationsView()
        }
    }

    private var categoryIcon: String {
        switch suggestion.category {
        case "meal", "food": return "fork.knife"
        case "exercise", "walk": return "figure.walk"
        case "hydration", "water": return "drop.fill"
        case "rest", "break": return "pause.circle"
        case "sleep": return "moon.fill"
        default: return "sparkles"
        }
    }

    private var categoryColor: Color {
        switch suggestion.category {
        case "meal", "food": return DesignSystem.Colors.amber
        case "exercise", "walk": return Color(hex: "34D399")
        case "hydration", "water": return DesignSystem.Colors.blue
        case "rest", "break": return Color(hex: "A78BFA")
        case "sleep": return DesignSystem.Colors.violet
        default: return DesignSystem.Colors.blue
        }
    }

    private var priorityColor: Color {
        switch suggestion.priority {
        case "high": return DesignSystem.Colors.errorRed
        case "medium": return DesignSystem.Colors.amber
        default: return Color(hex: "34D399")
        }
    }

    private func handleAction(_ action: String) {
        print("🔵 ClassySuggestionCard: handleAction called with action: '\(action)'")
        switch action {
        case "view_food_places":
            print("🟢 Opening Food Recommendations sheet")
            showFoodRecommendations = true
        case "view_walk_routes":
            print("🟢 Opening Walk Recommendations sheet")
            showWalkRecommendations = true
        default:
            print("⚠️ Unknown action: '\(action)'")
            break
        }
    }

    private func actionLabel(for action: String) -> String {
        switch action {
        case "view_food_places": return "View Places"
        case "view_walk_routes": return "View Routes"
        default: return "View"
        }
    }
}

// MARK: - Classy Breaks Section

struct ClassyBreaksSection: View {
    let recommendations: BreakRecommendations

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "A78BFA"))

                Text("Breaks")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()

                if let total = recommendations.totalRecommendedBreakMinutes {
                    Text("\(total) min total")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Strategy
            if let strategy = recommendations.overallBreakStrategy {
                Text(strategy)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(3)
            }

            // Break items
            if let breaks = recommendations.suggestedBreaks, !breaks.isEmpty {
                VStack(spacing: 10) {
                    ForEach(breaks.prefix(4)) { breakItem in
                        ClassyBreakItem(breakItem: breakItem)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct ClassyBreakItem: View {
    let breakItem: SuggestedBreak

    var body: some View {
        HStack(spacing: 14) {
            // Time
            Text(breakItem.displayTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)

            // Divider
            Rectangle()
                .fill(Color(hex: "A78BFA").opacity(0.3))
                .frame(width: 1, height: 30)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(breakItem.purpose?.capitalized ?? "Break")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                if let duration = breakItem.durationMinutes {
                    Text("\(duration) minutes")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Classy Alerts Section

struct ClassyAlertsSection: View {
    let alerts: [Alert]
    let isCritical: Bool

    var body: some View {
        VStack(spacing: 10) {
            ForEach(alerts) { alert in
                HStack(spacing: 12) {
                    Circle()
                        .fill(isCritical ? DesignSystem.Colors.errorRed : DesignSystem.Colors.amber)
                        .frame(width: 6, height: 6)

                    Text(cleanAlertMessage(alert.message))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(3)

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((isCritical ? DesignSystem.Colors.errorRed : DesignSystem.Colors.amber).opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke((isCritical ? DesignSystem.Colors.errorRed : DesignSystem.Colors.amber).opacity(0.15), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func cleanAlertMessage(_ message: String) -> String {
        var cleaned = message
        let emojiPrefixes = ["🚨 ", "⚠️ ", "💧 ", "😰 ", "✅ "]
        for prefix in emojiPrefixes {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        return cleaned
    }
}

// MARK: - Supporting Views

struct ClassyLoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.blue))
                .scaleEffect(1.2)

            Text("Preparing your summary")
                .font(.system(size: 15, weight: .light))
                .tracking(1)
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

struct ClassyErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(DesignSystem.Colors.amber)

            VStack(spacing: 8) {
                Text("Unable to load")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            Button(action: onRetry) {
                Text("Try Again")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.blue)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .stroke(DesignSystem.Colors.blue.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 40)
    }
}

struct ClassyEmptyView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.text")
                .font(.system(size: 40, weight: .thin))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 8) {
                Text("No summary yet")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)

                Text("Your daily summary will appear here")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

struct ClassyDatePicker: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(DesignSystem.Colors.blue)
                    .colorScheme(.dark)
                    .padding()

                    Spacer()
                }
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.blue)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Character Extension

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && scalar.value > 0x238C
    }
}

// MARK: - Preview

#Preview {
    DailySummaryView()
        .environmentObject(DailySummaryViewModel())
}
