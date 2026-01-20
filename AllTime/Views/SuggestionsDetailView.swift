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
            .navigationTitle("Actions")
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
                color: DesignSystem.Colors.amber
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
                color: DesignSystem.Colors.emerald
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

            Text("No actions available")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text("Check back later for personalized actions")
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
        case "view_walk_routes":
            showingWalkRoutes = true
        case "open_map":
            // Check category to determine what to show
            // Nutrition/lunch = food places, Movement/walk = walk routes
            if suggestion.category == "nutrition" {
                showingFoodPlaces = true
            } else {
                showingWalkRoutes = true
            }
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
    @State private var isAddingToCalendar = false
    @State private var isAddingToReminder = false
    @State private var calendarSuccess = false
    @State private var reminderSuccess = false
    @State private var errorMessage: String?

    private let apiService = APIService()

    // Parsed dates
    private var startDate: Date? {
        parseSuggestionDate(suggestion.recommendedStart)
    }

    private var endDate: Date? {
        if let end = parseSuggestionDate(suggestion.recommendedEnd) {
            return end
        }
        // Calculate from start + duration
        if let start = startDate, let duration = suggestion.durationMinutes {
            return start.addingTimeInterval(TimeInterval(duration * 60))
        }
        return nil
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Icon
                ZStack {
                    Circle()
                        .fill(suggestion.categoryColor.opacity(0.15))
                        .frame(width: 72, height: 72)
                    Image(systemName: suggestion.displayIcon)
                        .font(.system(size: 28))
                        .foregroundColor(suggestion.categoryColor)
                }
                .padding(.top, 24)

                // Title
                Text(suggestion.title)
                    .font(.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.center)

                // Time info card
                if let start = startDate {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .font(.subheadline)
                                .foregroundColor(suggestion.categoryColor)
                            Text("Suggested Time")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        Text(formatDateTimeDisplay(start))
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if let duration = suggestion.durationMinutes {
                            Text("\(duration) minutes")
                                .font(.subheadline)
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                    .padding(.horizontal)
                }

                // Error message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    // Add to Calendar button
                    Button(action: addToCalendar) {
                        HStack {
                            if isAddingToCalendar {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else if calendarSuccess {
                                Image(systemName: "checkmark")
                            } else {
                                Image(systemName: "calendar.badge.plus")
                            }
                            Text(calendarSuccess ? "Added to Calendar" : "Add to Calendar")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(calendarSuccess ? Color.green : suggestion.categoryColor)
                        )
                    }
                    .disabled(isAddingToCalendar || calendarSuccess || startDate == nil)

                    // Add to Reminders button
                    Button(action: addToReminders) {
                        HStack {
                            if isAddingToReminder {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: suggestion.categoryColor))
                            } else if reminderSuccess {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "bell.badge.fill")
                            }
                            Text(reminderSuccess ? "Reminder Created" : "Add to Reminders")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(reminderSuccess ? .green : suggestion.categoryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(reminderSuccess ? Color.green : suggestion.categoryColor, lineWidth: 2)
                        )
                    }
                    .disabled(isAddingToReminder || reminderSuccess || startDate == nil)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Date Parsing

    private func parseSuggestionDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }

        // Try multiple date formats
        let formatters: [DateFormatter] = [
            // ISO8601 with timezone
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            // ISO8601 without timezone (backend format)
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                return f
            }(),
            // With milliseconds
            {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone.current
                return f
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        // Try ISO8601DateFormatter as fallback
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: dateString) {
            return date
        }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: dateString)
    }

    private func formatDateTimeDisplay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Actions

    private func addToCalendar() {
        guard let start = startDate, let end = endDate else {
            errorMessage = "Invalid time for this action"
            return
        }

        isAddingToCalendar = true
        errorMessage = nil

        Task {
            do {
                let response = try await FocusTimeService.shared.blockFocusTime(
                    start: start,
                    end: end,
                    title: suggestion.title,
                    enableFocusMode: false
                )

                await MainActor.run {
                    isAddingToCalendar = false
                    if response.success {
                        calendarSuccess = true
                        // Auto-dismiss if both actions complete or after delay
                        if reminderSuccess {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
                        }
                    } else {
                        errorMessage = "Failed to add to calendar"
                    }
                }
            } catch {
                await MainActor.run {
                    isAddingToCalendar = false
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func addToReminders() {
        guard let start = startDate else {
            errorMessage = "Invalid time for this action"
            return
        }

        isAddingToReminder = true
        errorMessage = nil

        Task {
            do {
                // Create reminder using direct API call to avoid decoding issues
                let success = try await createReminderDirectly(
                    title: suggestion.title,
                    description: suggestion.description,
                    dueDate: start
                )

                await MainActor.run {
                    isAddingToReminder = false
                    if success {
                        reminderSuccess = true
                        // Auto-dismiss if both actions complete
                        if calendarSuccess {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
                        }
                    } else {
                        errorMessage = "Failed to create reminder"
                    }
                }
            } catch {
                await MainActor.run {
                    isAddingToReminder = false
                    errorMessage = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Create reminder with direct API call to handle response properly
    private func createReminderDirectly(title: String, description: String?, dueDate: Date) async throws -> Bool {
        guard let token = KeychainManager.shared.getAccessToken() else {
            throw NSError(domain: "AllTime", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/reminders") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // Format date as LocalDateTime string (WITHOUT timezone - backend expects yyyy-MM-dd'T'HH:mm:ss)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        let dueDateString = dateFormatter.string(from: dueDate)

        // Build JSON manually to ensure correct format
        let body: [String: Any] = [
            "title": title,
            "description": description ?? "",
            "due_date": dueDateString,
            "reminder_minutes_before": 15,
            "priority": "medium",
            "notification_enabled": true,
            "notification_sound": "default"
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🔔 Creating reminder: \(title) at \(dueDateString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }

        // Log response for debugging
        if httpResponse.statusCode != 201 {
            if let responseStr = String(data: data, encoding: .utf8) {
                print("🔔 Reminder creation failed: \(responseStr)")
            }
        }

        // 201 Created = success, we don't need to decode the response
        let success = httpResponse.statusCode == 201
        print("🔔 Reminder creation status: \(httpResponse.statusCode)")

        // Post notification to refresh reminders list
        if success {
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("RefreshReminders"), object: nil)
            }
        }

        return success
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
