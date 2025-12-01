import SwiftUI

struct DailySummaryView: View {
    @EnvironmentObject var summaryViewModel: DailySummaryViewModel
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Date Selector - Sticky Header
                        HStack {
                            Button(action: {
                                showingDatePicker = true
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 16, weight: .medium))
                                    Text(summaryViewModel.selectedDate, style: .date)
                                        .font(DesignSystem.Typography.body)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(DesignSystem.Colors.primary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    await summaryViewModel.refreshSummary()
                                    // Auto-scroll to top after refresh
                                    try? await Task.sleep(nanoseconds: 100_000_000) // Small delay to ensure content is loaded
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                }
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(DesignSystem.Colors.primary)
                                    .rotationEffect(.degrees(summaryViewModel.isLoading ? 360 : 0))
                                    .animation(summaryViewModel.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: summaryViewModel.isLoading)
                            }
                            .disabled(summaryViewModel.isLoading)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(Color(.systemBackground))
                        .id("top")
                        
                        // Content
                        if summaryViewModel.isLoading && summaryViewModel.summary == nil {
                            // Only show loading if we don't have any data (including cached)
                            LoadingView()
                                .padding(.top, 60)
                        } else if let summary = summaryViewModel.summary {
                            SummaryContentView(summary: summary)
                                .padding(.top, DesignSystem.Spacing.md)
                        } else if let errorMessage = summaryViewModel.errorMessage {
                            ErrorView(message: errorMessage) {
                                Task {
                                    await summaryViewModel.refreshSummary()
                                }
                            }
                            .padding(.top, 60)
                        } else {
                            EmptyStateView()
                                .padding(.top, 60)
                        }
                    }
                    .padding(.bottom, 85) // Reserve space for tab bar
                }
            }
            .navigationTitle("Daily Summary")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(selectedDate: $summaryViewModel.selectedDate)
            }
            .onAppear {
                // Load summary when view appears
                // If we already have summary, don't reload to avoid showing loading spinner
                if summaryViewModel.summary == nil {
                    // No data - load (will check cache first, show instantly)
                    Task {
                        await summaryViewModel.loadSummary(for: summaryViewModel.selectedDate)
                    }
                }
                // If we have data, don't reload - user can pull to refresh if needed
            }
            .onChange(of: summaryViewModel.selectedDate) { oldDate, newDate in
                // Reload summary when date changes
                Task {
                    await summaryViewModel.loadSummary(for: newDate)
                }
            }
        }
    }
}

// MARK: - Summary Content View
struct SummaryContentView: View {
    let summary: DailyAISummaryResponse
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Overall Summary - Larger Header
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                    
                    Text("Overview")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                
                // Adaptive text with better line spacing
                Text(summary.overallSummary)
                    .font(DesignSystem.Typography.body)
                    .lineSpacing(6)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.lg)
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAppeared)
            
            // Section Divider
            if !summary.keyHighlights.isEmpty || !summary.risksOrConflicts.isEmpty || !summary.suggestions.isEmpty {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            // Key Highlights
            if !summary.keyHighlights.isEmpty {
                HighlightSection(highlights: summary.keyHighlights)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: hasAppeared)
            }
            
            // Section Divider
            if !summary.risksOrConflicts.isEmpty || !summary.suggestions.isEmpty {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            // Risks & Conflicts
            if !summary.risksOrConflicts.isEmpty {
                RisksSection(risks: summary.risksOrConflicts)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.3), value: hasAppeared)
            }
            
            // Section Divider
            if !summary.suggestions.isEmpty {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            // Suggestions
            if !summary.suggestions.isEmpty {
                SuggestionsSection(suggestions: summary.suggestions)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: hasAppeared)
            }
            
            // Health-Based Suggestions (NEW)
            if let healthSuggestions = summary.healthBasedSuggestions, !healthSuggestions.isEmpty {
                // Section Divider
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                
                HealthBasedSuggestionsSection(suggestions: healthSuggestions)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: hasAppeared)
            }
            
            // Health Impact Insights (NEW)
            if let healthInsights = summary.healthImpactInsights {
                // Section Divider
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                
                HealthImpactInsightsSection(insights: healthInsights)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.6), value: hasAppeared)
            }
            
            // Metadata Footer removed - no longer showing event count or model info
        }
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Highlight Section
struct HighlightSection: View {
    let highlights: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.yellow)
                Text("Key Highlights")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(highlights, id: \.self) { highlight in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)
                        
                        Text(highlight)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Risks Section
struct RisksSection: View {
    let risks: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
                Text("Potential Issues")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(risks, id: \.self) { risk in
                    HStack(alignment: .top, spacing: 12) {
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .padding(.top, 8)
                        
                        Text(risk)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Suggestions Section
struct SuggestionsSection: View {
    let suggestions: [FreeTimeSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
                Text("Suggestions")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Metadata Footer (Removed - no longer displaying event count or model info)

// MARK: - Loading View
struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(DesignSystem.Colors.primary)
            
            Text("Generating your daily summary...")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Unable to load summary")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.primary.opacity(0.6))
            
            Text("No summary available")
                .font(DesignSystem.Typography.title3)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text("Your AI-powered daily summary will appear here")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Suggestion Card
struct SuggestionCard: View {
    let suggestion: FreeTimeSuggestion
    
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only show time if both start and end times are available
            if let startTime = suggestion.startTime, 
               let endTime = suggestion.endTime,
               !startTime.isEmpty, !endTime.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                    
                    if let startDate = Self.iso8601Formatter.date(from: startTime),
                       let endDate = Self.iso8601Formatter.date(from: endTime) {
                        Text("\(Self.timeFormatter.string(from: startDate)) - \(Self.timeFormatter.string(from: endDate))")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    } else {
                        Text("\(startTime) - \(endTime)")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }
            }
            
            Text(suggestion.suggestion)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let reason = suggestion.reason, !reason.isEmpty {
                Text(reason)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Health-Based Suggestions Section (NEW)
struct HealthBasedSuggestionsSection: View {
    let suggestions: [HealthBasedSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("Health-Based Suggestions")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 4)
            
            LazyVStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    HealthSuggestionCard(suggestion: suggestion)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Health Suggestion Card
struct HealthSuggestionCard: View {
    let suggestion: HealthBasedSuggestion
    
    private var categoryColor: Color {
        switch suggestion.category.lowercased() {
        case "exercise": return .orange
        case "sleep": return .indigo
        case "nutrition": return .green
        case "stress": return .red
        case "time_management": return .blue
        default: return DesignSystem.Colors.primary
        }
    }
    
    private var priorityColor: Color {
        switch suggestion.priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return DesignSystem.Colors.secondaryText
        }
    }
    
    private var categoryIcon: String {
        switch suggestion.category.lowercased() {
        case "exercise": return "figure.walk"
        case "sleep": return "moon.fill"
        case "nutrition": return "fork.knife"
        case "stress": return "heart.circle.fill"
        case "time_management": return "clock.fill"
        default: return "heart.text.square"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with category and priority
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: categoryIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(categoryColor)
                    Text(suggestion.category.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(categoryColor)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(categoryColor.opacity(0.15))
                .cornerRadius(6)
                
                Spacer()
                
                if let suggestedTime = suggestion.suggestedTime, !suggestedTime.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 11))
                        Text(suggestedTime)
                            .font(DesignSystem.Typography.caption2)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                // Priority badge
                Text(suggestion.priority.capitalized)
                    .font(DesignSystem.Typography.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(priorityColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(priorityColor.opacity(0.15))
                    .cornerRadius(4)
            }
            
            // Title
            Text(suggestion.title)
                .font(DesignSystem.Typography.body)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            // Description
            Text(suggestion.description)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Related event (if available)
            if let relatedEvent = suggestion.relatedEvent, !relatedEvent.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11))
                    Text("Related: \(relatedEvent)")
                        .font(DesignSystem.Typography.caption)
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .padding(.top, 2)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .strokeBorder(categoryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Health Impact Insights Section (NEW)
struct HealthImpactInsightsSection: View {
    let insights: HealthImpactInsights
    
    // Helper function to clean JSON formatting from summary text
    private static func cleanSummaryText(_ text: String) -> String {
        var cleaned = text
            .replacingOccurrences(of: "{\"summary\": \"", with: "")
            .replacingOccurrences(of: "\"}", with: "")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any remaining JSON structure
        if cleaned.hasPrefix("{") {
            cleaned = String(cleaned.dropFirst())
        }
        if cleaned.hasSuffix("}") {
            cleaned = String(cleaned.dropLast())
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.info)
                Text("Health Impact Insights")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 16) {
                // Summary - clean up any JSON-like formatting
                if let summary = insights.summary, !summary.isEmpty {
                    let cleanedSummary = Self.cleanSummaryText(summary)
                    
                    Text(cleanedSummary)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                // Key Correlations
                if let correlations = insights.keyCorrelations, !correlations.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Key Correlations")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        ForEach(correlations, id: \.self) { correlation in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "link")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.info)
                                    .padding(.top, 2)
                                
                                Text(correlation)
                                    .font(DesignSystem.Typography.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                    }
                }
                
                // Health Trends
                if let trends = insights.healthTrends {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Health Trends")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            if let sleep = trends.sleep {
                                TrendItemView(metric: "Sleep", trend: sleep)
                            }
                            if let steps = trends.steps {
                                TrendItemView(metric: "Steps", trend: steps)
                            }
                            if let activeMinutes = trends.activeMinutes {
                                TrendItemView(metric: "Active Minutes", trend: activeMinutes)
                            }
                            if let rhr = trends.restingHeartRate {
                                TrendItemView(metric: "Resting HR", trend: rhr)
                            }
                            if let hrv = trends.hrv {
                                TrendItemView(metric: "HRV", trend: hrv)
                            }
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Trend Item View
struct TrendItemView: View {
    let metric: String
    let trend: String
    
    private var trendColor: Color {
        switch trend.lowercased() {
        case "improving": return .green
        case "declining": return .red
        case "stable": return .orange
        default: return DesignSystem.Colors.secondaryText
        }
    }
    
    private var trendIcon: String {
        switch trend.lowercased() {
        case "improving": return "arrow.up.right"
        case "declining": return "arrow.down.right"
        case "stable": return "arrow.right"
        default: return "minus"
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: trendIcon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(trendColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(metric)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                Text(trend.capitalized)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(trendColor)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(trendColor.opacity(0.1))
        )
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DailySummaryView()
        .environmentObject(DailySummaryViewModel())
}
