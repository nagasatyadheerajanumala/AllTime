import SwiftUI

// MARK: - Classy Design Components
// Unified elegant styling matching SignInView

// MARK: - Section Card (Legacy Support)

struct SectionCard: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: sectionIcon)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "3B82F6"))

                Text(cleanTitle)
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))

                Spacer()
            }

            // Items - no truncation
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color(hex: "3B82F6").opacity(0.5))
                            .frame(width: 4, height: 4)
                            .padding(.top, 7)

                        Text(cleanItemText(item))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private var cleanTitle: String {
        var cleaned = title
        // Remove emoji prefixes
        while let first = cleaned.first, first.isEmoji || first == " " {
            cleaned = String(cleaned.dropFirst())
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    private var sectionIcon: String {
        if title.contains("Day") || title.contains("Calendar") { return "calendar" }
        if title.contains("Health") || title.contains("Recovery") { return "heart" }
        if title.contains("Focus") || title.contains("Productivity") { return "target" }
        if title.contains("Break") { return "clock" }
        return "doc.text"
    }

    private func cleanItemText(_ text: String) -> String {
        var cleaned = text
        if cleaned.hasPrefix("  •") || cleaned.hasPrefix("  →") {
            cleaned = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }
}

// MARK: - Alerts Banner

struct AlertsBanner: View {
    let alerts: [Alert]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(alerts) { alert in
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(severityColor(for: alert.severity))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)

                    Text(cleanAlertMessage(alert.message))
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(severityColor(for: alert.severity).opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(severityColor(for: alert.severity).opacity(0.15), lineWidth: 1)
                        )
                )
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func severityColor(for severity: AlertSeverity) -> Color {
        switch severity {
        case .critical: return Color(hex: "EF4444")
        case .warning: return Color(hex: "F59E0B")
        case .info: return Color(hex: "3B82F6")
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

// MARK: - Water Intake Widget

struct WaterIntakeWidget: View {
    let current: Double
    let goal: Double

    private var progress: Double {
        min(current / goal, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14, weight: .light))
                        .foregroundColor(Color(hex: "3B82F6"))

                    Text("Hydration")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                Text(String(format: "%.1f / %.1f L", current, goal))
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "3B82F6"), Color(hex: "60A5FA")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * CGFloat(progress), height: 8)
                }
            }
            .frame(height: 8)

            // Status
            Text(statusMessage)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
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

    private var statusMessage: String {
        let remaining = goal - current
        if remaining <= 0 {
            return "Goal achieved"
        } else {
            return String(format: "%.1fL remaining", remaining)
        }
    }
}

// MARK: - Break Recommendations View

struct BreakRecommendationsView: View {
    let breaks: [BreakWindow]
    let strategy: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let strategy = strategy {
                Text(strategy)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(3)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(breaks) { breakWindow in
                        BreakCard(breakWindow: breakWindow)
                    }
                }
            }
        }
    }
}

struct BreakCard: View {
    let breakWindow: BreakWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: breakIcon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(Color(hex: "A78BFA"))

                Spacer()

                Text("\(breakWindow.duration)m")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text(formattedTime)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text(breakWindow.type.displayName)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(14)
        .frame(width: 110)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var breakIcon: String {
        switch breakWindow.type {
        case .hydration: return "drop.fill"
        case .meal: return "fork.knife"
        case .rest: return "moon.fill"
        case .movement: return "figure.walk"
        case .prep: return "list.clipboard"
        }
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: breakWindow.time)
    }
}

// MARK: - Summary Metrics Card

struct SummaryMetricsCard: View {
    let waterIntake: Double?
    let waterGoal: Double?
    let steps: Int?
    let stepsGoal: Int?
    let sleepHours: Double?

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Today")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
            }

            HStack(spacing: 20) {
                if let sleep = sleepHours {
                    MetricItem(
                        icon: "moon.fill",
                        iconColor: Color(hex: "A78BFA"),
                        value: String(format: "%.1f", sleep),
                        unit: "hrs",
                        label: "Sleep"
                    )
                }

                if let steps = steps {
                    MetricItem(
                        icon: "figure.walk",
                        iconColor: Color(hex: "34D399"),
                        value: formatNumber(steps),
                        unit: "",
                        label: "Steps"
                    )
                }

                if let water = waterIntake {
                    MetricItem(
                        icon: "drop.fill",
                        iconColor: Color(hex: "3B82F6"),
                        value: String(format: "%.1f", water),
                        unit: "L",
                        label: "Water"
                    )
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

    private func formatNumber(_ number: Int) -> String {
        return number.formatted()
    }
}

struct MetricItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let unit: String
    let label: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(iconColor)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Text(label)
                .font(.system(size: 11, weight: .regular))
                .tracking(1)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Health Suggestions Grid

struct HealthSuggestionsGrid: View {
    let suggestions: [DailySummarySuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "F59E0B"))

                Text("Suggestions")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    HealthSuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

struct HealthSuggestionCard: View {
    let suggestion: DailySummarySuggestion
    @State private var showFoodRecommendations = false
    @State private var showWalkRecommendations = false
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(categoryColor)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(categoryColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    if let time = suggestion.suggestedTime {
                        Text(time)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()

                Circle()
                    .fill(priorityColor)
                    .frame(width: 6, height: 6)
            }

            // Description - expandable for long text
            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.55))
                    .lineSpacing(3)
                    .lineLimit(isExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)

                if suggestion.description.count > 150 {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show Less" : "Show More")
                                .font(.system(size: 12, weight: .medium))
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(categoryColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let action = suggestion.action {
                Button(action: {
                    print("🔴 HealthSuggestionCard Button tapped! Action: '\(action)'")
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(categoryColor.opacity(0.2), lineWidth: 1)
                )
        )
        .fixedSize(horizontal: false, vertical: true)
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
        case "meal", "food": return Color(hex: "F59E0B")
        case "exercise", "walk": return Color(hex: "34D399")
        case "hydration", "water": return Color(hex: "3B82F6")
        case "rest", "break": return Color(hex: "A78BFA")
        case "sleep": return Color(hex: "8B5CF6")
        default: return Color(hex: "3B82F6")
        }
    }

    private var priorityColor: Color {
        switch suggestion.priority {
        case "high": return Color(hex: "EF4444")
        case "medium": return Color(hex: "F59E0B")
        default: return Color(hex: "34D399")
        }
    }

    private func handleAction(_ action: String) {
        print("🔵 HealthSuggestionCard: handleAction called with action: '\(action)'")
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

struct SuggestionPriorityBadge: View {
    let priority: String

    var body: some View {
        Circle()
            .fill(priorityColor)
            .frame(width: 6, height: 6)
    }

    private var priorityColor: Color {
        switch priority {
        case "high": return Color(hex: "EF4444")
        case "medium": return Color(hex: "F59E0B")
        default: return Color(hex: "34D399")
        }
    }
}

// MARK: - API Break Recommendations Card

struct APIBreakRecommendationsCard: View {
    let recommendations: BreakRecommendations

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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
                    Text("\(total) min")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            if let strategy = recommendations.overallBreakStrategy {
                Text(strategy)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineSpacing(3)
            }

            if let breaks = recommendations.suggestedBreaks, !breaks.isEmpty {
                VStack(spacing: 10) {
                    ForEach(breaks) { breakItem in
                        APIBreakTimelineItem(breakItem: breakItem)
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

struct APIBreakTimelineItem: View {
    let breakItem: SuggestedBreak

    var body: some View {
        HStack(spacing: 14) {
            Text(breakItem.displayTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 60, alignment: .leading)

            Rectangle()
                .fill(Color(hex: "A78BFA").opacity(0.3))
                .frame(width: 1, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(breakItem.purpose?.capitalized ?? "Break")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                if let duration = breakItem.durationMinutes {
                    Text("\(duration) min")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Pattern Insights Card

struct PatternInsightsCard: View {
    let insights: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "A78BFA"))

                Text("Patterns")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color(hex: "A78BFA").opacity(0.5))
                            .frame(width: 4, height: 4)
                            .padding(.top, 7)

                        Text(cleanInsight(insight))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "A78BFA").opacity(0.15), lineWidth: 1)
                )
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func cleanInsight(_ insight: String) -> String {
        var cleaned = insight
        while let first = cleaned.first, first.isEmoji || first == " " {
            cleaned = String(cleaned.dropFirst())
        }
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Location Recommendations Card

struct LocationRecommendationsCard: View {
    let recommendations: LocationRecommendations

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "3B82F6"))

                if let city = recommendations.userCity {
                    Text(city)
                        .font(.system(size: 13, weight: .medium))
                        .tracking(2)
                        .textCase(.uppercase)
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()
            }

            if let lunch = recommendations.lunchRecommendation {
                LunchRecommendationView(recommendation: lunch)
            }

            if let routes = recommendations.walkRoutes, !routes.isEmpty {
                WalkRoutesView(routes: routes, message: recommendations.walkMessage)
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

struct LunchRecommendationView: View {
    let recommendation: LunchRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "fork.knife")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(Color(hex: "F59E0B"))

                Text("Lunch Spots")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()

                if let time = recommendation.recommendationTime {
                    Text(time)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            if let spots = recommendation.nearbySpots, !spots.isEmpty {
                ForEach(spots) { spot in
                    SimpleLunchSpotRow(spot: spot)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "F59E0B").opacity(0.05))
        )
    }
}

struct SimpleLunchSpotRow: View {
    let spot: SimpleLunchSpot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                if let cuisine = spot.cuisine {
                    Text(cuisine)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let distance = spot.distance {
                    Text(distance)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }

                if let rating = spot.rating {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "F59E0B"))
                        Text(String(format: "%.1f", rating))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

struct WalkRoutesView: View {
    let routes: [WalkRoute]
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(Color(hex: "34D399"))

                Text("Walk Routes")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Spacer()
            }

            ForEach(routes) { route in
                WalkRouteRow(route: route)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "34D399").opacity(0.05))
        )
    }
}

struct WalkRouteRow: View {
    let route: WalkRoute

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(route.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                if let type = route.type {
                    Text(type.capitalized)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if let distance = route.distance {
                    Text(distance)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.5))
                }

                if let duration = route.duration {
                    Text(duration)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "34D399"))
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// Character.isEmoji extension defined in DailySummaryView.swift

// MARK: - Previews

#Preview("Section Card") {
    SectionCard(
        title: "📅 Your Day",
        items: [
            "You have 5 meetings scheduled",
            "  • Sprint Planning at 10:00 AM",
            "  • 1-on-1 at 2:00 PM"
        ]
    )
    .padding()
    .background(Color.black)
}

#Preview("Metrics") {
    SummaryMetricsCard(
        waterIntake: 1.2,
        waterGoal: 2.5,
        steps: 8500,
        stepsGoal: 10000,
        sleepHours: 7.5
    )
    .padding()
    .background(Color.black)
}
