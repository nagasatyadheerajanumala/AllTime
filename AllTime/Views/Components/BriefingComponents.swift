import SwiftUI

// MARK: - Quick Stats Header
struct QuickStatsHeader: View {
    let quickStats: QuickStats

    var body: some View {
        HStack(spacing: 0) {
            // Meetings Count
            QuickStatItem(
                icon: "calendar",
                value: "\(quickStats.meetingsCount ?? 0)",
                label: "Meetings",
                color: DesignSystem.Colors.primary
            )

            Divider()
                .frame(height: 40)
                .background(DesignSystem.Colors.tertiaryText.opacity(0.3))

            // Focus Time
            QuickStatItem(
                icon: "brain.head.profile",
                value: quickStats.focusTimeAvailable ?? "0h",
                label: "Focus Time",
                color: DesignSystem.Colors.emerald
            )

            Divider()
                .frame(height: 40)
                .background(DesignSystem.Colors.tertiaryText.opacity(0.3))

            // Health Label
            QuickStatItem(
                icon: "heart.fill",
                value: quickStats.healthLabel ?? "Good",
                label: "Health",
                color: DesignSystem.Colors.errorRed
            )

            Divider()
                .frame(height: 40)
                .background(DesignSystem.Colors.tertiaryText.opacity(0.3))

            // Energy Forecast
            QuickStatItem(
                icon: "bolt.fill",
                value: quickStats.energyForecast ?? "Steady",
                label: "Energy",
                color: DesignSystem.Colors.amber
            )
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.tertiaryText.opacity(0.1), lineWidth: 1)
        )
    }
}

struct QuickStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let briefing: DailyBriefingResponse
    @State private var isSuggestionExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Mood badge and date
            HStack {
                // Mood badge
                HStack(spacing: 6) {
                    Image(systemName: briefing.moodIcon)
                        .font(.system(size: 12, weight: .medium))
                    Text(briefing.moodLabel)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(briefing.moodGradient)
                )

                Spacer()

                // Generated time
                if !briefing.generatedAt.isEmpty {
                    Text(briefing.generatedAt.toRelativeTime())
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }

            // Summary line - always show full
            Text(briefing.summaryLine)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Top suggestion preview - expandable
            if let topSuggestion = briefing.quickStats?.topSuggestion, !topSuggestion.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.amber)

                        Text(topSuggestion)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(3)
                            .lineLimit(isSuggestionExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if topSuggestion.count > 100 {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSuggestionExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(isSuggestionExpanded ? "Show Less" : "Show More")
                                    .font(.caption.weight(.medium))
                                Image(systemName: isSuggestionExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(DesignSystem.Colors.amber)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DesignSystem.Colors.amber.opacity(0.1))
                )
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.tertiaryText.opacity(0.1), lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Suggestion Card
struct SuggestionCard: View {
    let suggestion: BriefingSuggestion
    var onAction: (() -> Void)? = nil
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
                    RoundedRectangle(cornerRadius: 12)
                        .fill(suggestion.categoryColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(suggestion.categoryColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let description = suggestion.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(2)
                            .lineLimit(isExpanded ? nil : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Time and severity
                    HStack(spacing: 8) {
                        if let time = suggestion.effectiveTimeLabel, !time.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(time.toReadableTime())
                                    .font(.caption2)
                            }
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }

                        if let severity = suggestion.severity, !severity.isEmpty {
                            Text(severity.capitalized)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(suggestion.severityColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(suggestion.severityColor.opacity(0.15))
                                )
                        }
                    }

                    // Primary action label if available
                    if let actionLabel = suggestion.effectiveActionLabel {
                        Button(action: { handleAction(suggestion.effectiveActionType) }) {
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
                }

                Spacer()

                // Action button if available
                if suggestion.effectiveActionType != nil {
                    Button(action: { handleAction(suggestion.effectiveActionType) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }

            // Show More/Less for long descriptions
            if let description = suggestion.description, description.count > 120 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show Less" : "Show More")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 60) // Align with text
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

    /// Parses date/time strings in various formats from the backend
    private func parseFlexibleDateTime(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }

        // Try ISO8601 formats first
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try various DateFormatter patterns
        let patterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "HH:mm:ss",
            "HH:mm"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for pattern in patterns {
            formatter.dateFormat = pattern

            // Try with current timezone
            formatter.timeZone = TimeZone.current
            if let date = formatter.date(from: dateString) {
                // For time-only formats (HH:mm, HH:mm:ss), combine with today's date
                if pattern == "HH:mm" || pattern == "HH:mm:ss" {
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
                    var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                    todayComponents.hour = timeComponents.hour
                    todayComponents.minute = timeComponents.minute
                    todayComponents.second = timeComponents.second
                    return calendar.date(from: todayComponents)
                }
                return date
            }

            // Try with UTC
            formatter.timeZone = TimeZone(identifier: "UTC")
            if let date = formatter.date(from: dateString) {
                if pattern == "HH:mm" || pattern == "HH:mm:ss" {
                    let calendar = Calendar.current
                    let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: date)
                    var todayComponents = calendar.dateComponents([.year, .month, .day], from: Date())
                    todayComponents.hour = timeComponents.hour
                    todayComponents.minute = timeComponents.minute
                    todayComponents.second = timeComponents.second
                    return calendar.date(from: todayComponents)
                }
                return date
            }
        }

        print("⚠️ BlockTime: Could not parse date string: '\(dateString)'")
        return nil
    }

    private func handleAction(_ actionType: String?) {
        print("🔵 SuggestionCard: handleAction called with actionType: '\(actionType ?? "nil")', category: '\(suggestion.category ?? "nil")'")

        // First try the callback if provided
        if let onAction = onAction {
            print("🔵 SuggestionCard: Using external onAction callback")
            onAction()
            return
        }

        // Otherwise handle internally
        guard let actionType = actionType else {
            print("⚠️ SuggestionCard: actionType is nil")
            return
        }

        // For open_map actions, check category to route to appropriate list view
        let category = (suggestion.category ?? "").lowercased()

        switch actionType {
        case "view_food_places":
            print("🟢 SuggestionCard: Opening Food Recommendations sheet")
            showFoodRecommendations = true
        case "view_walk_routes":
            print("🟢 SuggestionCard: Opening Walk Recommendations sheet")
            showWalkRecommendations = true
        case "block_time", "open_calendar":
            print("🟢 SuggestionCard: Blocking time")
            blockTime()
        case "open_map", "open_maps":
            // Check category to determine if this should show a list first
            if category == "nutrition" || category == "meal" || category == "food" || category == "lunch" {
                print("🟢 SuggestionCard: Category is food-related, opening Food Recommendations sheet")
                showFoodRecommendations = true
            } else if category == "exercise" || category == "activity" || category == "movement" || category == "walk" || category == "wellness" {
                print("🟢 SuggestionCard: Category is walk-related, opening Walk Recommendations sheet")
                showWalkRecommendations = true
            } else {
                print("🟢 SuggestionCard: Opening Maps directly")
                openMaps()
            }
        default:
            print("⚠️ SuggestionCard: Unknown action: '\(actionType)'")
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

        print("🔵 BlockTime: recommendedStart = '\(suggestion.recommendedStart ?? "nil")', recommendedEnd = '\(suggestion.recommendedEnd ?? "nil")'")

        let startDate = parseFlexibleDateTime(suggestion.recommendedStart)
        let endDate = parseFlexibleDateTime(suggestion.recommendedEnd)

        print("🔵 BlockTime: Parsed startDate = \(startDate?.description ?? "nil"), endDate = \(endDate?.description ?? "nil")")

        // If we couldn't parse the times, show an error instead of using current time
        guard let start = startDate else {
            blockTimeMessage = "Could not determine the recommended time. Please try again later."
            showBlockTimeError = true
            return
        }

        let end = endDate ?? start.addingTimeInterval(3600)

        isBlockingTime = true

        Task {
            do {
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: start,
                    end: end,
                    title: suggestion.title,
                    enableFocusMode: true
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

// MARK: - Suggestions Section
struct SuggestionsSection: View {
    let suggestions: [BriefingSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.amber)

                Text("Suggestions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Text("\(suggestions.count)")
                    .font(.caption.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)

            // Suggestion cards
            ForEach(suggestions, id: \.suggestionId) { suggestion in
                SuggestionCard(suggestion: suggestion)
            }
        }
    }
}

// MARK: - Focus Window Card
struct FocusWindowCard: View {
    let focusWindow: FocusWindow
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Time indicator
                VStack(spacing: 4) {
                    Circle()
                        .fill(DesignSystem.Colors.primary)
                        .frame(width: 10, height: 10)

                    Rectangle()
                        .fill(DesignSystem.Colors.primary.opacity(0.3))
                        .frame(width: 2, height: 30)

                    Circle()
                        .stroke(DesignSystem.Colors.primary, lineWidth: 2)
                        .frame(width: 10, height: 10)
                }

                // Content
                VStack(alignment: .leading, spacing: 6) {
                    // Time range
                    Text(TimeRangeFormatter.format(start: focusWindow.startTime, end: focusWindow.endTime, compact: true))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    // Duration
                    Text(TimeRangeFormatter.formatDuration(minutes: focusWindow.durationMinutes))
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    // Suggested activity
                    if let activity = focusWindow.suggestedActivity, !activity.isEmpty {
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
                    if let reason = focusWindow.reason, !reason.isEmpty {
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

                // Badges
                VStack(alignment: .trailing, spacing: 6) {
                    // Confidence badge
                    if !focusWindow.confidenceBadge.isEmpty {
                        Text(focusWindow.confidenceBadge)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(focusWindow.confidenceColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(focusWindow.confidenceColor.opacity(0.15))
                            )
                    }

                    // Quality score
                    if let score = focusWindow.qualityScore {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                            Text("\(score)")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(DesignSystem.Colors.amber)
                    }
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
                .stroke(DesignSystem.Colors.primary.opacity(0.2), lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Focus Windows Section
struct FocusWindowsSection: View {
    let focusWindows: [FocusWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)

                Text("Focus Windows")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Text("\(focusWindows.count) available")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)

            // Focus window cards
            ForEach(focusWindows, id: \.windowId) { window in
                FocusWindowCard(focusWindow: window)
            }
        }
    }
}

// MARK: - Energy Dip Card
struct EnergyDipCard: View {
    let energyDip: EnergyDip
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Severity icon
                ZStack {
                    Circle()
                        .fill(energyDip.severityColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: energyDip.severityIcon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(energyDip.severityColor)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Time
                    HStack(spacing: 6) {
                        Text(energyDip.displayTime.toReadableTime())
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(energyDip.severity.capitalized)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(energyDip.severityColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(energyDip.severityColor.opacity(0.15))
                            )
                    }

                    // Time range if available
                    if let endTime = energyDip.displayEndTime, !endTime.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text("\(energyDip.displayTime.toReadableTime()) - \(endTime.toReadableTime())")
                                .font(.caption2)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    // Recommendation - expandable
                    if let recommendation = energyDip.recommendation, !recommendation.isEmpty {
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
                    if let reason = energyDip.reason, !reason.isEmpty {
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
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(energyDip.severityColor.opacity(0.2), lineWidth: 1)
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Energy Dips Section
struct EnergyDipsSection: View {
    let energyDips: [EnergyDip]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "battery.50")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.amber)

                Text("Energy Dips")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                Text("\(energyDips.count) predicted")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)

            // Energy dip cards
            ForEach(energyDips, id: \.dipId) { dip in
                EnergyDipCard(energyDip: dip)
            }
        }
    }
}

// MARK: - Key Metrics Section
struct KeyMetricsSection: View {
    let metrics: BriefingKeyMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)

                Text("Key Metrics")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)

            // Metrics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                if let meetings = metrics.totalMeetings {
                    MetricTile(
                        icon: "calendar",
                        value: "\(meetings)",
                        label: "Meetings",
                        color: DesignSystem.Colors.primary
                    )
                }

                if let focusTime = metrics.focusTimeAvailable {
                    MetricTile(
                        icon: "brain.head.profile",
                        value: String(format: "%.1fh", focusTime),
                        label: "Focus Time",
                        color: DesignSystem.Colors.emerald
                    )
                }

                if let steps = metrics.stepsToday {
                    MetricTile(
                        icon: "figure.walk",
                        value: steps.formatted(),
                        label: "Steps",
                        color: DesignSystem.Colors.amber
                    )
                }

                if let sleepScore = metrics.sleepScore {
                    MetricTile(
                        icon: "moon.fill",
                        value: "\(sleepScore)",
                        label: "Sleep Score",
                        color: DesignSystem.Colors.violet
                    )
                }

                if let activeMinutes = metrics.activeMinutes {
                    MetricTile(
                        icon: "flame.fill",
                        value: "\(activeMinutes)m",
                        label: "Active Time",
                        color: DesignSystem.Colors.errorRed
                    )
                }

                if let longestFreeBlock = metrics.longestFreeBlock {
                    MetricTile(
                        icon: "clock",
                        value: TimeRangeFormatter.formatDuration(minutes: longestFreeBlock),
                        label: "Longest Free",
                        color: Color(hex: "06B6D4")
                    )
                }
            }
        }
    }
}

struct MetricTile: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(label)
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(DesignSystem.Colors.tertiaryText.opacity(0.1), lineWidth: 1)
        )
    }
}
