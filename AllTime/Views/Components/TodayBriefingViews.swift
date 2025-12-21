import SwiftUI

// MARK: - Greeting Header View
struct GreetingHeaderView: View {
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text(dateText)
                .font(.title2.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Daily Summary Card View
struct DailySummaryCardView: View {
    let briefing: DailyBriefingResponse

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Top row: Mood pill + timestamp
            HStack {
                // Mood pill
                HStack(spacing: 6) {
                    Image(systemName: briefing.moodIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(briefing.moodLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(moodColor)
                )

                Spacer()

                // Timestamp
                Text(briefing.generatedAt.toRelativeTime())
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            // Summary text
            Text(briefing.summaryLine)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(moodBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(moodColor.opacity(0.3), lineWidth: 1)
        )
    }

    private var moodColor: Color {
        switch briefing.mood.lowercased() {
        case "focus_day", "focused":
            return Color(hex: "3B82F6")
        case "light_day", "light":
            return Color(hex: "10B981")
        case "intense_meetings", "intense", "busy":
            return Color(hex: "F59E0B")
        case "rest_day", "rest", "recovery":
            return Color(hex: "8B5CF6")
        default:
            return DesignSystem.Colors.primary
        }
    }

    private var moodBackgroundColor: Color {
        switch briefing.mood.lowercased() {
        case "focus_day", "focused":
            return Color(hex: "3B82F6").opacity(0.08)
        case "light_day", "light":
            return Color(hex: "10B981").opacity(0.08)
        case "intense_meetings", "intense", "busy":
            return Color(hex: "F59E0B").opacity(0.08)
        case "rest_day", "rest", "recovery":
            return Color(hex: "8B5CF6").opacity(0.08)
        default:
            return DesignSystem.Colors.cardBackground
        }
    }
}

// MARK: - Today's Plan Section
struct TodaysPlanSection: View {
    let suggestions: [BriefingSuggestion]

    // Get top 3 suggestions sorted by priority/severity
    private var topSuggestions: [BriefingSuggestion] {
        let sorted = suggestions.sorted { s1, s2 in
            let p1 = severityPriority(s1.severity)
            let p2 = severityPriority(s2.severity)
            if p1 != p2 { return p1 > p2 }
            return (s1.priority ?? 0) > (s2.priority ?? 0)
        }
        return Array(sorted.prefix(3))
    }

    private func severityPriority(_ severity: String?) -> Int {
        switch (severity ?? "").lowercased() {
        case "critical", "important", "high": return 4
        case "alert", "warning": return 3
        case "medium", "reminder": return 2
        case "info", "low": return 1
        default: return 0
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(hex: "F59E0B"))

                Text("Today's Plan")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            // Top 3 suggestion cards
            ForEach(topSuggestions, id: \.suggestionId) { suggestion in
                PlanCard(suggestion: suggestion)
            }
        }
    }
}

// MARK: - Plan Card (Larger suggestion card for Today's Plan)
struct PlanCard: View {
    let suggestion: BriefingSuggestion
    @State private var isExpanded = false
    @State private var showFoodRecommendations = false
    @State private var showWalkRecommendations = false
    @State private var isBlockingTime = false
    @State private var showBlockTimeSuccess = false
    @State private var showBlockTimeError = false
    @State private var blockTimeMessage: String = ""
    @State private var focusModeUrl: String?

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(suggestion.categoryColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: suggestion.displayIcon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(suggestion.categoryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                // Title row with optional severity pill
                HStack(alignment: .top) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    if let severity = suggestion.severity, !severity.isEmpty {
                        Text(severityLabel(severity))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(suggestion.severityColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(suggestion.severityColor.opacity(0.15))
                            )
                    }
                }

                // Description - expandable for long text
                if let description = suggestion.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(3)
                            .lineLimit(isExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)

                        // Show More/Less button for long descriptions
                        if description.count > 120 {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Text(isExpanded ? "Show Less" : "Show More")
                                        .font(.caption2.weight(.medium))
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Time if available (use new timeLabel field or fall back to suggestedTime)
                if let time = suggestion.effectiveTimeLabel, !time.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(time.toReadableTime())
                            .font(.caption2)
                    }
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                // Action buttons row
                if suggestion.hasAction || suggestion.hasSecondaryAction {
                    HStack(spacing: 12) {
                        // Primary action button
                        if let actionLabel = suggestion.effectiveActionLabel {
                            Button(action: {
                                handleAction(suggestion.effectiveActionType)
                            }) {
                                HStack(spacing: 4) {
                                    Text(actionLabel)
                                        .font(.caption.weight(.medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .medium))
                                }
                                .foregroundColor(suggestion.categoryColor)
                            }
                            .buttonStyle(.plain)
                        }

                        // Secondary action button (e.g., "Add to Calendar" for lunch/walk)
                        if suggestion.hasSecondaryAction, let secondaryLabel = suggestion.secondaryActionLabel {
                            Button(action: {
                                handleAction(suggestion.secondaryActionType)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.system(size: 10, weight: .medium))
                                    Text(secondaryLabel)
                                        .font(.caption.weight(.medium))
                                }
                                .foregroundColor(DesignSystem.Colors.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.tertiaryText.opacity(0.1), lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showFoodRecommendations) {
            FoodRecommendationsView(
                suggestedStartTime: parsedStartDate,
                suggestedEndTime: parsedEndDate,
                suggestionTitle: suggestion.title
            )
        }
        .sheet(isPresented: $showWalkRecommendations) {
            WalkRecommendationsView(
                suggestedStartTime: parsedStartDate,
                suggestedEndTime: parsedEndDate,
                suggestionTitle: suggestion.title
            )
        }
        .alert("Focus Time Blocked!", isPresented: $showBlockTimeSuccess) {
            Button("OK") {}
            if focusModeUrl != nil {
                Button("Enable Focus Mode") {
                    FocusTimeService.shared.triggerFocusModeShortcut(shortcutUrl: focusModeUrl)
                }
            }
        } message: {
            Text(blockTimeMessage)
        }
        .alert("Unable to Block Time", isPresented: $showBlockTimeError) {
            Button("OK") {}
        } message: {
            Text(blockTimeMessage)
        }
    }

    // Computed properties to parse dates from suggestion
    private var parsedStartDate: Date? {
        guard let startStr = suggestion.recommendedStart else { return nil }
        return parseISO8601Date(startStr)
    }

    private var parsedEndDate: Date? {
        guard let endStr = suggestion.recommendedEnd else { return nil }
        return parseISO8601Date(endStr)
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func handleAction(_ actionType: String?) {
        print("🔵 PlanCard: handleAction called with actionType: '\(actionType ?? "nil")', category: '\(suggestion.category ?? "nil")'")
        guard let actionType = actionType else {
            print("⚠️ PlanCard: actionType is nil")
            return
        }

        // For open_map actions, check category to route to appropriate list view
        let category = (suggestion.category ?? "").lowercased()

        switch actionType {
        case "view_food_places":
            print("🟢 PlanCard: Opening Food Recommendations sheet")
            showFoodRecommendations = true
        case "view_walk_routes":
            print("🟢 PlanCard: Opening Walk Recommendations sheet")
            showWalkRecommendations = true
        case "add_to_calendar", "block_time", "open_calendar":
            print("🟢 PlanCard: Blocking time for \(suggestion.title)")
            blockTime()
        case "open_map", "open_maps":
            // Check category to determine if this should show a list first
            if category == "nutrition" || category == "meal" || category == "food" || category == "lunch" {
                print("🟢 PlanCard: Category is food-related, opening Food Recommendations sheet")
                showFoodRecommendations = true
            } else if category == "exercise" || category == "activity" || category == "movement" || category == "walk" || category == "wellness" {
                print("🟢 PlanCard: Category is walk-related, opening Walk Recommendations sheet")
                showWalkRecommendations = true
            } else {
                print("🟢 PlanCard: Opening Maps directly")
                openMaps()
            }
        default:
            print("⚠️ PlanCard: Unknown action: '\(actionType)'")
            break
        }
    }

    private func openMaps() {
        // Try to get location from suggestion metadata
        var latitude: Double?
        var longitude: Double?
        var locationName: String?

        if let metadata = suggestion.metadata {
            latitude = metadata["latitude"]?.doubleValue
            longitude = metadata["longitude"]?.doubleValue
            locationName = metadata["location_name"]?.stringValue ?? metadata["name"]?.stringValue
        }

        // If we have coordinates, open Maps with them
        if let lat = latitude, let lon = longitude {
            let name = locationName ?? suggestion.title
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedName)") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback: search for the suggestion title in Maps
        let searchQuery = locationName ?? suggestion.title
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedQuery)") {
            UIApplication.shared.open(url)
        }
    }

    private func blockTime() {
        guard !isBlockingTime else { return }

        // Parse start and end times from suggestion
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var startDate: Date?
        var endDate: Date?

        // Try to parse recommendedStart/recommendedEnd
        if let startStr = suggestion.recommendedStart {
            startDate = formatter.date(from: startStr)
            // Try without fractional seconds if that fails
            if startDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                startDate = formatter.date(from: startStr)
            }
        }

        if let endStr = suggestion.recommendedEnd {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            endDate = formatter.date(from: endStr)
            if endDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                endDate = formatter.date(from: endStr)
            }
        }

        // Get duration from metadata if available, otherwise calculate from times
        var suggestedDuration: Int? = nil
        if let metadata = suggestion.metadata {
            suggestedDuration = metadata["suggested_duration_minutes"]?.intValue ?? suggestion.durationMinutes
        }

        // Calculate start and end times
        var start: Date
        var end: Date

        if let startDate = startDate, let endDate = endDate {
            // Use the exact times from the backend
            start = startDate
            end = endDate
            print("🎯 PlanCard blockTime: Using exact times from backend - start: \(start), end: \(end)")
        } else if let startDate = startDate, let duration = suggestedDuration {
            // Use start time and calculate end from duration
            start = startDate
            end = startDate.addingTimeInterval(TimeInterval(duration * 60))
            print("🎯 PlanCard blockTime: Using start time + duration - start: \(start), end: \(end)")
        } else {
            // Fallback: use current time + 1 hour (or duration from metadata)
            start = Date()
            let durationMinutes = suggestedDuration ?? 60
            end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            print("⚠️ PlanCard blockTime: No times provided, using fallback - start: \(start), end: \(end)")
        }

        // Get title from metadata if available
        var blockTitle = suggestion.title
        if let metadata = suggestion.metadata, let metaTitle = metadata["block_title"]?.stringValue {
            blockTitle = metaTitle
        }

        // Check if focus mode should be enabled (from metadata)
        var enableFocusMode = true
        if let metadata = suggestion.metadata, let enableFocus = metadata["enable_focus_mode"]?.boolValue {
            enableFocusMode = enableFocus
        }

        isBlockingTime = true

        Task {
            do {
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: start,
                    end: end,
                    title: blockTitle,
                    enableFocusMode: enableFocusMode
                )

                await MainActor.run {
                    isBlockingTime = false
                    if response.success {
                        blockTimeMessage = response.message ?? "Calendar event created successfully."
                        focusModeUrl = response.focusMode?.shortcutUrl
                        showBlockTimeSuccess = true
                    } else {
                        blockTimeMessage = response.message ?? "Failed to create calendar event."
                        showBlockTimeError = true
                    }
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

    private func severityLabel(_ severity: String) -> String {
        switch severity.lowercased() {
        case "critical", "high": return "Important"
        case "warning", "medium": return "Reminder"
        default: return "Info"
        }
    }
}

// MARK: - Quick Stats Row View
struct QuickStatsRowView: View {
    let quickStats: QuickStats?
    let keyMetrics: BriefingKeyMetrics?

    var body: some View {
        HStack(spacing: 0) {
            // Meetings
            QuickStatItem(
                icon: "calendar",
                value: meetingsLabel,
                label: "Meetings",
                color: DesignSystem.Colors.primary
            )

            quickDivider

            // Focus Time
            QuickStatItem(
                icon: "brain.head.profile",
                value: focusLabel,
                label: "Focus",
                color: Color(hex: "10B981")
            )

            quickDivider

            // Health
            QuickStatItem(
                icon: "heart.fill",
                value: healthLabel,
                label: "Health",
                color: Color(hex: "EF4444")
            )

            quickDivider

            // Energy
            QuickStatItem(
                icon: "bolt.fill",
                value: energyLabel,
                label: "Energy",
                color: Color(hex: "F59E0B")
            )
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }

    private var quickDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.tertiaryText.opacity(0.2))
            .frame(width: 1, height: 40)
    }

    private var meetingsLabel: String {
        if let count = quickStats?.meetingsCount {
            return "\(count)"
        }
        if let metrics = keyMetrics {
            return "\(metrics.effectiveMeetingsCount)"
        }
        return "0"
    }

    private var focusLabel: String {
        if let focus = quickStats?.focusTimeAvailable {
            return focus
        }
        if let metrics = keyMetrics {
            let hours = metrics.effectiveFreeHours
            if hours > 0 {
                return String(format: "%.0fh", hours)
            }
        }
        return "—"
    }

    private var healthLabel: String {
        if let score = quickStats?.healthScore {
            return "\(score)"
        }
        return quickStats?.healthLabel ?? "Good"
    }

    private var energyLabel: String {
        quickStats?.energyForecast ?? keyMetrics?.energyLevel ?? "Steady"
    }
}

// QuickStatItem is defined in BriefingComponents.swift

// MARK: - Insights Accordion Section
struct InsightsAccordionSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let badge: String?
    let isExpanded: Bool
    let onToggle: () -> Void
    let content: AnyView

    var body: some View {
        VStack(spacing: 0) {
            // Header button
            Button(action: onToggle) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(iconColor)

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let badge = badge {
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(DesignSystem.Colors.cardBackgroundElevated)
                            )
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
            .buttonStyle(.plain)

            // Expandable content
            if isExpanded {
                content
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - All Suggestions List
struct AllSuggestionsList: View {
    let suggestions: [BriefingSuggestion]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(suggestions, id: \.suggestionId) { suggestion in
                CompactSuggestionCard(suggestion: suggestion)
            }
        }
    }
}

struct CompactSuggestionCard: View {
    let suggestion: BriefingSuggestion
    @State private var isExpanded = false
    @State private var showFoodRecommendations = false
    @State private var showWalkRecommendations = false
    @State private var isBlockingTime = false
    @State private var showBlockTimeSuccess = false
    @State private var showBlockTimeError = false
    @State private var blockTimeMessage: String = ""
    @State private var focusModeUrl: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(suggestion.categoryColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(suggestion.categoryColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = suggestion.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(2)
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Time label if available
                    if let time = suggestion.effectiveTimeLabel, !time.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 9))
                            Text(time.toReadableTime())
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    // Action buttons row
                    if suggestion.hasAction || suggestion.hasSecondaryAction {
                        HStack(spacing: 12) {
                            // Primary action button
                            if let actionLabel = suggestion.effectiveActionLabel {
                                Button(action: {
                                    handleAction(suggestion.effectiveActionType)
                                }) {
                                    HStack(spacing: 4) {
                                        Text(actionLabel)
                                            .font(.caption.weight(.medium))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(suggestion.categoryColor)
                                }
                                .buttonStyle(.plain)
                            }

                            // Secondary action button (e.g., "Add to Calendar" for lunch/walk)
                            if suggestion.hasSecondaryAction, let secondaryLabel = suggestion.secondaryActionLabel {
                                Button(action: {
                                    handleAction(suggestion.secondaryActionType)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar.badge.plus")
                                            .font(.system(size: 10, weight: .medium))
                                        Text(secondaryLabel)
                                            .font(.caption.weight(.medium))
                                    }
                                    .foregroundColor(DesignSystem.Colors.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 2)
                    }
                }

                Spacer()

                // Severity indicator
                if let severity = suggestion.severity, !severity.isEmpty {
                    Circle()
                        .fill(suggestion.severityColor)
                        .frame(width: 8, height: 8)
                }
            }

            // Show More/Less for long descriptions
            if let description = suggestion.description, description.count > 100 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption2.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 52) // Align with text
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
        .fixedSize(horizontal: false, vertical: true)
        .sheet(isPresented: $showFoodRecommendations) {
            FoodRecommendationsView(
                suggestedStartTime: parsedStartDate,
                suggestedEndTime: parsedEndDate,
                suggestionTitle: suggestion.title
            )
        }
        .sheet(isPresented: $showWalkRecommendations) {
            WalkRecommendationsView(
                suggestedStartTime: parsedStartDate,
                suggestedEndTime: parsedEndDate,
                suggestionTitle: suggestion.title
            )
        }
        .alert("Focus Time Blocked!", isPresented: $showBlockTimeSuccess) {
            Button("OK") {}
            if focusModeUrl != nil {
                Button("Enable Focus Mode") {
                    FocusTimeService.shared.triggerFocusModeShortcut(shortcutUrl: focusModeUrl)
                }
            }
        } message: {
            Text(blockTimeMessage)
        }
        .alert("Unable to Block Time", isPresented: $showBlockTimeError) {
            Button("OK") {}
        } message: {
            Text(blockTimeMessage)
        }
    }

    // Computed properties to parse dates from suggestion
    private var parsedStartDate: Date? {
        guard let startStr = suggestion.recommendedStart else { return nil }
        return parseISO8601Date(startStr)
    }

    private var parsedEndDate: Date? {
        guard let endStr = suggestion.recommendedEnd else { return nil }
        return parseISO8601Date(endStr)
    }

    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func handleAction(_ actionType: String?) {
        print("🔵 CompactSuggestionCard: handleAction called with actionType: '\(actionType ?? "nil")', category: '\(suggestion.category ?? "nil")'")
        guard let actionType = actionType else {
            print("⚠️ CompactSuggestionCard: actionType is nil")
            return
        }

        // For open_map actions, check category to route to appropriate list view
        let category = (suggestion.category ?? "").lowercased()

        switch actionType {
        case "view_food_places":
            print("🟢 CompactSuggestionCard: Opening Food Recommendations sheet")
            showFoodRecommendations = true
        case "view_walk_routes":
            print("🟢 CompactSuggestionCard: Opening Walk Recommendations sheet")
            showWalkRecommendations = true
        case "add_to_calendar", "block_time", "open_calendar":
            print("🟢 CompactSuggestionCard: Blocking time for \(suggestion.title)")
            blockTime()
        case "open_map", "open_maps":
            // Check category to determine if this should show a list first
            if category == "nutrition" || category == "meal" || category == "food" || category == "lunch" {
                print("🟢 CompactSuggestionCard: Category is food-related, opening Food Recommendations sheet")
                showFoodRecommendations = true
            } else if category == "exercise" || category == "activity" || category == "movement" || category == "walk" || category == "wellness" {
                print("🟢 CompactSuggestionCard: Category is walk-related, opening Walk Recommendations sheet")
                showWalkRecommendations = true
            } else {
                print("🟢 CompactSuggestionCard: Opening Maps directly")
                openMaps()
            }
        default:
            print("⚠️ CompactSuggestionCard: Unknown action: '\(actionType)'")
            break
        }
    }

    private func openMaps() {
        // Try to get location from suggestion metadata
        var latitude: Double?
        var longitude: Double?
        var locationName: String?

        if let metadata = suggestion.metadata {
            latitude = metadata["latitude"]?.doubleValue
            longitude = metadata["longitude"]?.doubleValue
            locationName = metadata["location_name"]?.stringValue ?? metadata["name"]?.stringValue
        }

        // If we have coordinates, open Maps with them
        if let lat = latitude, let lon = longitude {
            let name = locationName ?? suggestion.title
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "maps://?ll=\(lat),\(lon)&q=\(encodedName)") {
                UIApplication.shared.open(url)
                return
            }
        }

        // Fallback: search for the suggestion title in Maps
        let searchQuery = locationName ?? suggestion.title
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?q=\(encodedQuery)") {
            UIApplication.shared.open(url)
        }
    }

    private func blockTime() {
        guard !isBlockingTime else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var startDate: Date?
        var endDate: Date?

        if let startStr = suggestion.recommendedStart {
            startDate = formatter.date(from: startStr)
            if startDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                startDate = formatter.date(from: startStr)
            }
        }

        if let endStr = suggestion.recommendedEnd {
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            endDate = formatter.date(from: endStr)
            if endDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                endDate = formatter.date(from: endStr)
            }
        }

        // Get duration from metadata if available
        var suggestedDuration: Int? = nil
        if let metadata = suggestion.metadata {
            suggestedDuration = metadata["suggested_duration_minutes"]?.intValue ?? suggestion.durationMinutes
        }

        // Calculate start and end times
        var start: Date
        var end: Date

        if let startDate = startDate, let endDate = endDate {
            // Use the exact times from the backend
            start = startDate
            end = endDate
            print("🎯 CompactCard blockTime: Using exact times from backend - start: \(start), end: \(end)")
        } else if let startDate = startDate, let duration = suggestedDuration {
            // Use start time and calculate end from duration
            start = startDate
            end = startDate.addingTimeInterval(TimeInterval(duration * 60))
            print("🎯 CompactCard blockTime: Using start time + duration - start: \(start), end: \(end)")
        } else {
            // Fallback: use current time + duration (or 1 hour default)
            start = Date()
            let durationMinutes = suggestedDuration ?? 60
            end = start.addingTimeInterval(TimeInterval(durationMinutes * 60))
            print("⚠️ CompactCard blockTime: No times provided, using fallback - start: \(start), end: \(end)")
        }

        // Get title from metadata if available
        var blockTitle = suggestion.title
        if let metadata = suggestion.metadata, let metaTitle = metadata["block_title"]?.stringValue {
            blockTitle = metaTitle
        }

        // Check if focus mode should be enabled (from metadata)
        var enableFocusMode = true
        if let metadata = suggestion.metadata, let enableFocus = metadata["enable_focus_mode"]?.boolValue {
            enableFocusMode = enableFocus
        }

        isBlockingTime = true

        Task {
            do {
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: start,
                    end: end,
                    title: blockTitle,
                    enableFocusMode: enableFocusMode
                )

                await MainActor.run {
                    isBlockingTime = false
                    if response.success {
                        blockTimeMessage = response.message ?? "Calendar event created successfully."
                        focusModeUrl = response.focusMode?.shortcutUrl
                        showBlockTimeSuccess = true
                    } else {
                        blockTimeMessage = response.message ?? "Failed to create calendar event."
                        showBlockTimeError = true
                    }
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
}

// MARK: - Focus Windows List
struct FocusWindowsList: View {
    let focusWindows: [FocusWindow]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(focusWindows, id: \.windowId) { window in
                FocusWindowRow(window: window)
            }
        }
    }
}

struct FocusWindowRow: View {
    let window: FocusWindow
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Time indicator
                VStack(spacing: 2) {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 8, height: 8)
                    Rectangle()
                        .fill(DesignSystem.Colors.primary.opacity(0.3))
                        .frame(width: 2, height: 20)
                    Circle()
                        .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                        .frame(width: 8, height: 8)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(TimeRangeFormatter.format(start: window.startTime, end: window.endTime, compact: true))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(TimeRangeFormatter.formatDuration(minutes: window.durationMinutes))
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    // Suggested activity if available
                    if let activity = window.suggestedActivity, !activity.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text(activity)
                                .font(.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    // Reason - expandable for long text
                    if let reason = window.reason, !reason.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(reason)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                                .lineSpacing(2)
                                .lineLimit(isExpanded ? nil : 2)
                                .fixedSize(horizontal: false, vertical: true)

                            if reason.count > 80 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(isExpanded ? "Show Less" : "Show More")
                                            .font(.caption2.weight(.medium))
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(DesignSystem.Colors.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                // Quality/confidence badges
                VStack(alignment: .trailing, spacing: 4) {
                    if let score = window.qualityScore {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text("\(score)")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundColor(Color(hex: "F59E0B"))
                    }

                    if !window.confidenceBadge.isEmpty {
                        Text(window.confidenceBadge)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(window.confidenceColor)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.primary.opacity(0.2), lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Energy Dips List
struct EnergyDipsList: View {
    let energyDips: [EnergyDip]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(energyDips, id: \.dipId) { dip in
                EnergyDipRow(dip: dip)
            }
        }
    }
}

struct EnergyDipRow: View {
    let dip: EnergyDip
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Severity icon
                ZStack {
                    Circle()
                        .fill(dip.severityColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: dip.severityIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(dip.severityColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(dip.label ?? dip.displayTime.toReadableTime())
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        // Severity pill
                        Text(severityLabel(dip.severity))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(dip.severityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(dip.severityColor.opacity(0.15))
                            )
                    }

                    // Time range if available
                    if let endTime = dip.displayEndTime, !endTime.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(dip.displayTime.toReadableTime()) - \(endTime.toReadableTime())")
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    // Recommendation - expandable
                    if let recommendation = dip.recommendation, !recommendation.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineSpacing(2)
                                .lineLimit(isExpanded ? nil : 3)
                                .fixedSize(horizontal: false, vertical: true)

                            if recommendation.count > 100 {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isExpanded.toggle()
                                    }
                                }) {
                                    HStack(spacing: 4) {
                                        Text(isExpanded ? "Show Less" : "Show More")
                                            .font(.caption2.weight(.medium))
                                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 9, weight: .medium))
                                    }
                                    .foregroundColor(DesignSystem.Colors.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Reason - always show full
                    if let reason = dip.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
        .fixedSize(horizontal: false, vertical: true)
    }

    private func severityLabel(_ severity: String) -> String {
        switch severity.lowercased() {
        case "high", "critical", "significant": return "Significant"
        case "medium", "moderate": return "Moderate"
        default: return "Mild"
        }
    }
}

// MARK: - Detailed Summary View (Accordion Content)
struct DetailedSummaryContent: View {
    let briefing: DailyBriefingResponse

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Key metrics breakdown
            if let metrics = briefing.keyMetrics {
                DetailedMetricsSection(metrics: metrics)
            }

            // Data sources info
            if briefing.dataSources != nil {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Data from calendar, health, and activity sources")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .padding(.top, DesignSystem.Spacing.sm)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
    }
}

struct DetailedMetricsSection: View {
    let metrics: BriefingKeyMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Schedule metrics
            if hasScheduleMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Schedule", systemImage: "calendar")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        let meetingsCount = metrics.effectiveMeetingsCount
                        if meetingsCount > 0 {
                            DetailMetricRow(label: "Total meetings", value: "\(meetingsCount)")
                        }
                        let meetingHours = metrics.effectiveMeetingHours
                        if meetingHours > 0 {
                            DetailMetricRow(label: "Meeting hours", value: String(format: "%.1fh", meetingHours))
                        }
                        let freeHours = metrics.effectiveFreeHours
                        if freeHours > 0 {
                            DetailMetricRow(label: "Free time", value: String(format: "%.1fh", freeHours))
                        }
                        let longestBlock = metrics.effectiveLongestFreeBlock
                        if longestBlock > 0 {
                            DetailMetricRow(label: "Longest free block", value: TimeRangeFormatter.formatDuration(minutes: longestBlock))
                        }
                    }
                }
            }

            // Health metrics
            if hasHealthMetrics {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Health", systemImage: "heart.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        // Sleep metrics (new API fields first, then legacy)
                        if let sleepHours = metrics.sleepHoursLastNight {
                            DetailMetricRow(label: "Sleep last night", value: String(format: "%.1fh", sleepHours))
                        }
                        if let sleepQuality = metrics.sleepQualityScore {
                            DetailMetricRow(label: "Sleep quality", value: "\(sleepQuality)")
                        } else if let sleep = metrics.sleepScore {
                            DetailMetricRow(label: "Sleep score", value: "\(sleep)")
                        }
                        // Steps (new API uses stepsYesterday, legacy uses stepsToday)
                        if let steps = metrics.stepsYesterday {
                            DetailMetricRow(label: "Steps yesterday", value: steps.formatted())
                        } else if let steps = metrics.stepsToday {
                            DetailMetricRow(label: "Steps today", value: steps.formatted())
                        }
                        // Active minutes (new API uses activeMinutesYesterday, legacy uses activeMinutes)
                        if let active = metrics.activeMinutesYesterday {
                            DetailMetricRow(label: "Active minutes yesterday", value: "\(active) min")
                        } else if let active = metrics.activeMinutes {
                            DetailMetricRow(label: "Active minutes", value: "\(active) min")
                        }
                        // Heart metrics (new API)
                        if let rhr = metrics.restingHeartRate {
                            DetailMetricRow(label: "Resting heart rate", value: "\(rhr) BPM")
                        }
                        if let hrv = metrics.hrvLastNight {
                            DetailMetricRow(label: "HRV last night", value: "\(hrv) ms")
                        }
                    }
                }
            }
        }
    }

    private var hasScheduleMetrics: Bool {
        metrics.meetingsTodayCount != nil || metrics.totalMeetings != nil ||
        metrics.totalMeetingHoursToday != nil || metrics.meetingHours != nil ||
        metrics.freeHoursToday != nil || metrics.freeTimeHours != nil
    }

    private var hasHealthMetrics: Bool {
        metrics.sleepHoursLastNight != nil || metrics.sleepScore != nil ||
        metrics.stepsYesterday != nil || metrics.stepsToday != nil ||
        metrics.activeMinutesYesterday != nil || metrics.activeMinutes != nil ||
        metrics.restingHeartRate != nil || metrics.hrvLastNight != nil
    }
}

struct DetailMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
    }
}

// MARK: - Briefing Empty State
struct BriefingEmptyStateView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("Your briefing is being prepared")
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text("Check back in a moment")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Briefing Loading State
struct BriefingLoadingStateView: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Greeting skeleton
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonRect(width: 100, height: 14)
                    SkeletonRect(width: 160, height: 20)
                }
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Summary skeleton
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    SkeletonRect(width: 80, height: 24)
                    Spacer()
                    SkeletonRect(width: 60, height: 12)
                }
                SkeletonRect(height: 16)
                SkeletonRect(width: 200, height: 16)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Plan skeleton
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                SkeletonRect(width: 120, height: 18)
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: DesignSystem.Spacing.md) {
                        SkeletonRect(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonRect(height: 14)
                            SkeletonRect(width: 140, height: 12)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackgroundElevated)
                    )
                }
            }
        }
    }
}

struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    @State private var isAnimating = false

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(DesignSystem.Colors.cardBackgroundElevated)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .opacity(isAnimating ? 0.5 : 1.0)
            .animation(
                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Health Insights Card
/// Prominent health insights card showing sleep, activity, and personalized suggestions
struct HealthInsightsCard: View {
    let keyMetrics: BriefingKeyMetrics?
    let suggestions: [BriefingSuggestion]?
    let quickStats: QuickStats?

    // Filter health-related suggestions
    private var healthSuggestions: [BriefingSuggestion] {
        guard let suggestions = suggestions else { return [] }
        return suggestions.filter { suggestion in
            let category = suggestion.category?.lowercased() ?? ""
            return category == "health_insight" ||
                   category == "wellness" ||
                   category == "movement" ||
                   category == "sleep" ||
                   category == "recovery"
        }
    }

    // Determine energy level based on sleep and HRV
    private var energyLevel: (label: String, color: Color, icon: String) {
        guard let metrics = keyMetrics else {
            return ("Unknown", DesignSystem.Colors.secondaryText, "questionmark.circle")
        }

        let sleepHours = metrics.sleepHoursLastNight ?? metrics.effectiveSleepHours ?? 0
        let hrv = metrics.hrvLastNight

        if sleepHours >= 7 && (hrv == nil || hrv! >= 40) {
            return ("High Energy", Color(hex: "10B981"), "bolt.fill")
        } else if sleepHours >= 6 && (hrv == nil || hrv! >= 30) {
            return ("Moderate", Color(hex: "F59E0B"), "bolt")
        } else {
            return ("Low Energy", Color(hex: "EF4444"), "battery.25")
        }
    }

    private var hasHealthData: Bool {
        guard let metrics = keyMetrics else { return false }
        return metrics.sleepHoursLastNight != nil ||
               metrics.stepsYesterday != nil ||
               metrics.activeMinutesYesterday != nil
    }

    var body: some View {
        if hasHealthData || !healthSuggestions.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Color(hex: "EF4444"))

                    Text("Health Insights")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    // Energy badge
                    HStack(spacing: 4) {
                        Image(systemName: energyLevel.icon)
                            .font(.caption2)
                        Text(energyLevel.label)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundColor(energyLevel.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(energyLevel.color.opacity(0.15))
                    )
                }

                // Health Metrics Row
                if let metrics = keyMetrics {
                    healthMetricsRow(metrics: metrics)
                }

                // Health Suggestions
                if !healthSuggestions.isEmpty {
                    healthSuggestionsSection
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }

    @ViewBuilder
    private func healthMetricsRow(metrics: BriefingKeyMetrics) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Sleep metric
            if let sleepHours = metrics.sleepHoursLastNight ?? metrics.effectiveSleepHours {
                healthMetricItem(
                    icon: "moon.fill",
                    value: String(format: "%.1fh", sleepHours),
                    label: "Sleep",
                    comparison: sleepComparison(sleepHours, average: metrics.sleepHoursAverage),
                    color: sleepColor(sleepHours)
                )
            }

            // Steps metric
            if let steps = metrics.stepsYesterday ?? metrics.stepsToday {
                healthMetricItem(
                    icon: "figure.walk",
                    value: formatNumber(steps),
                    label: "Steps",
                    comparison: stepsComparison(steps, average: metrics.stepsAverage),
                    color: stepsColor(steps, average: metrics.stepsAverage)
                )
            }

            // Active minutes metric
            if let activeMin = metrics.activeMinutesYesterday ?? metrics.activeMinutes {
                healthMetricItem(
                    icon: "flame.fill",
                    value: "\(activeMin)m",
                    label: "Active",
                    comparison: activeMinComparison(activeMin, average: metrics.activeMinutesAverage),
                    color: activeMinColor(activeMin, average: metrics.activeMinutesAverage)
                )
            }
        }
    }

    @ViewBuilder
    private func healthMetricItem(icon: String, value: String, label: String, comparison: String?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.headline.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }

            Text(label)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            if let comparison = comparison {
                Text(comparison)
                    .font(.caption2)
                    .foregroundColor(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackgroundElevated)
        )
    }

    @ViewBuilder
    private var healthSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Recommendations")
                .font(.caption.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            ForEach(healthSuggestions.prefix(3), id: \.id) { suggestion in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: suggestion.displayIcon)
                        .font(.caption)
                        .foregroundColor(Color(hex: "10B981"))
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(1)

                        if let desc = suggestion.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(2)
                        }
                    }

                    Spacer()

                    if let timeLabel = suggestion.effectiveTimeLabel {
                        Text(timeLabel)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(Color(hex: "10B981").opacity(0.08))
                )
            }
        }
    }

    // MARK: - Helper Functions

    private func sleepComparison(_ hours: Double, average: Double?) -> String? {
        guard let avg = average else { return nil }
        let diff = hours - avg
        if abs(diff) < 0.3 { return "On track" }
        let sign = diff > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", diff))h vs avg"
    }

    private func sleepColor(_ hours: Double) -> Color {
        if hours >= 7 { return Color(hex: "10B981") }
        if hours >= 6 { return Color(hex: "F59E0B") }
        return Color(hex: "EF4444")
    }

    private func stepsComparison(_ steps: Int, average: Int?) -> String? {
        guard let avg = average, avg > 0 else { return nil }
        let percent = (Double(steps) / Double(avg)) * 100
        if percent >= 90 && percent <= 110 { return "On track" }
        return "\(Int(percent))% of avg"
    }

    private func stepsColor(_ steps: Int, average: Int?) -> Color {
        let target = average ?? 10000
        let percent = Double(steps) / Double(target)
        if percent >= 0.8 { return Color(hex: "10B981") }
        if percent >= 0.5 { return Color(hex: "F59E0B") }
        return Color(hex: "EF4444")
    }

    private func activeMinComparison(_ minutes: Int, average: Int?) -> String? {
        guard let avg = average, avg > 0 else { return nil }
        let percent = (Double(minutes) / Double(avg)) * 100
        if percent >= 90 && percent <= 110 { return "On track" }
        return "\(Int(percent))% of avg"
    }

    private func activeMinColor(_ minutes: Int, average: Int?) -> Color {
        let target = average ?? 30
        let percent = Double(minutes) / Double(target)
        if percent >= 0.8 { return Color(hex: "10B981") }
        if percent >= 0.5 { return Color(hex: "F59E0B") }
        return Color(hex: "EF4444")
    }

    private func formatNumber(_ num: Int) -> String {
        return num.formatted()
    }
}
