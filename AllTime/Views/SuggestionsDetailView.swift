import SwiftUI

// MARK: - Suggestions Detail View
struct SuggestionsDetailView: View {
    let briefing: DailyBriefingResponse?
    let suggestionsTile: SuggestionsTileData?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String? = nil

    private var suggestions: [BriefingSuggestion] {
        briefing?.suggestions ?? []
    }

    private var categories: [String] {
        let cats = Set(suggestions.compactMap { $0.category })
        return ["All"] + Array(cats).sorted()
    }

    private var filteredSuggestions: [BriefingSuggestion] {
        if selectedCategory == nil || selectedCategory == "All" {
            return suggestions
        }
        return suggestions.filter { $0.category == selectedCategory }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header stats
                    headerStats
                        .padding(.horizontal)

                    // Category filter
                    if categories.count > 2 {
                        categoryFilter
                    }

                    // Suggestions list
                    if filteredSuggestions.isEmpty {
                        emptyState
                    } else {
                        suggestionsListView
                            .padding(.horizontal)
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 16)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header Stats
    private var headerStats: some View {
        HStack(spacing: 16) {
            StatBox(
                value: "\(suggestions.count)",
                label: "Total",
                icon: "lightbulb.fill",
                color: Color(hex: "F59E0B")
            )

            StatBox(
                value: "\(suggestions.filter { $0.category == "focus" }.count)",
                label: "Focus",
                icon: "brain.head.profile",
                color: Color(hex: "5856D6")
            )

            StatBox(
                value: "\(suggestions.filter { $0.category == "movement" || $0.category == "nutrition" }.count)",
                label: "Wellness",
                icon: "heart.fill",
                color: Color(hex: "10B981")
            )
        }
    }

    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    CategoryChip(
                        title: category.capitalized,
                        isSelected: (selectedCategory ?? "All") == category,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = category == "All" ? nil : category
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Suggestions List
    private var suggestionsListView: some View {
        VStack(spacing: 12) {
            ForEach(filteredSuggestions, id: \.suggestionId) { suggestion in
                SuggestionDetailCard(suggestion: suggestion)
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lightbulb.slash")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            Text("No suggestions available")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text("Check back later for personalized recommendations")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
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

// MARK: - Category Chip
struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
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

// MARK: - Suggestion Detail Card
struct SuggestionDetailCard: View {
    let suggestion: BriefingSuggestion
    @State private var showingBlockTime = false
    @State private var showingFoodPlaces = false
    @State private var showingWalkRoutes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(suggestion.categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 18))
                        .foregroundColor(suggestion.categoryColor)
                }

                // Title and time
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(.headline)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let time = suggestion.effectiveTimeLabel {
                        Text(time)
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Severity badge
                if let severity = suggestion.severity {
                    Text(severity.capitalized)
                        .font(.caption.weight(.medium))
                        .foregroundColor(suggestion.severityColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(suggestion.severityColor.opacity(0.12))
                        )
                }
            }

            // Description
            if let description = suggestion.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Action buttons
            if suggestion.hasAction || suggestion.hasSecondaryAction {
                HStack(spacing: 12) {
                    if suggestion.hasAction {
                        actionButton(
                            label: suggestion.effectiveActionLabel ?? "Action",
                            type: suggestion.effectiveActionType ?? ""
                        )
                    }

                    if suggestion.hasSecondaryAction {
                        secondaryActionButton(
                            label: suggestion.secondaryActionLabel ?? "",
                            type: suggestion.secondaryActionType ?? ""
                        )
                    }

                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .sheet(isPresented: $showingBlockTime) {
            BlockTimeSheetView(suggestion: suggestion)
        }
        .sheet(isPresented: $showingFoodPlaces) {
            FoodRecommendationsView()
        }
        .sheet(isPresented: $showingWalkRoutes) {
            WalkRecommendationsView()
        }
    }

    @ViewBuilder
    private func actionButton(label: String, type: String) -> some View {
        Button(action: {
            handleAction(type: type)
        }) {
            HStack(spacing: 6) {
                Image(systemName: actionIcon(for: type))
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(suggestion.categoryColor)
            )
        }
    }

    @ViewBuilder
    private func secondaryActionButton(label: String, type: String) -> some View {
        Button(action: {
            handleAction(type: type)
        }) {
            HStack(spacing: 6) {
                Image(systemName: actionIcon(for: type))
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundColor(suggestion.categoryColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .strokeBorder(suggestion.categoryColor, lineWidth: 1.5)
            )
        }
    }

    private func actionIcon(for type: String) -> String {
        switch type {
        case "add_to_calendar", "block_time": return "calendar.badge.plus"
        case "view_food_places", "open_map": return "mappin.and.ellipse"
        case "view_walk_routes": return "figure.walk"
        case "open_health": return "heart.fill"
        default: return "arrow.right"
        }
    }

    private func handleAction(type: String) {
        switch type {
        case "add_to_calendar", "block_time":
            showingBlockTime = true
        case "view_food_places":
            showingFoodPlaces = true
        case "view_walk_routes", "open_map":
            showingWalkRoutes = true
        case "open_health":
            // Open Health app
            if let url = URL(string: "x-apple-health://") {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }
}

// MARK: - Block Time Sheet View
struct BlockTimeSheetView: View {
    let suggestion: BriefingSuggestion
    @Environment(\.dismiss) private var dismiss
    @State private var isBlocking = false
    @State private var blockSuccess = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(suggestion.categoryColor.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 32))
                        .foregroundColor(suggestion.categoryColor)
                }
                .padding(.top, 32)

                // Title
                Text(suggestion.title)
                    .font(.title2.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                // Time info
                if let start = suggestion.recommendedStart, let duration = suggestion.durationMinutes {
                    VStack(spacing: 4) {
                        Text("Suggested time")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        Text(formatDateTime(start))
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        Text("\(duration) minutes")
                            .font(.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Block time button
                Button(action: {
                    blockTime()
                }) {
                    HStack {
                        if isBlocking {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else if blockSuccess {
                            Image(systemName: "checkmark")
                        } else {
                            Image(systemName: "calendar.badge.plus")
                        }
                        Text(blockSuccess ? "Added to Calendar" : "Block Time")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(blockSuccess ? Color.green : suggestion.categoryColor)
                    )
                }
                .disabled(isBlocking || blockSuccess)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatDateTime(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return dateString
    }

    private func blockTime() {
        guard !isBlocking else { return }

        // Parse start and end times from suggestion
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

        // Calculate start and end times
        let start: Date
        let end: Date

        if let startDate = startDate, let endDate = endDate {
            start = startDate
            end = endDate
        } else if let startDate = startDate, let duration = suggestion.durationMinutes {
            start = startDate
            end = startDate.addingTimeInterval(TimeInterval(duration * 60))
        } else {
            // Fallback: use current time + 1 hour
            start = Date()
            end = start.addingTimeInterval(3600)
        }

        isBlocking = true

        Task {
            do {
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: start,
                    end: end,
                    title: suggestion.title,
                    enableFocusMode: false
                )

                await MainActor.run {
                    isBlocking = false
                    if response.success {
                        blockSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isBlocking = false
                    // Show error - for now just print
                    print("Failed to block time: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    SuggestionsDetailView(
        briefing: nil,
        suggestionsTile: SuggestionsTileData(
            previewLine: "Deep Work Block",
            count: 3,
            topSuggestions: nil
        )
    )
}
