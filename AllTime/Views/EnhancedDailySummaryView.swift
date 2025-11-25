import SwiftUI

/// Enhanced Daily Summary View using v1 API
struct EnhancedDailySummaryView: View {
    @StateObject private var viewModel = EnhancedDailySummaryViewModel()
    @State private var showingDatePicker = false
    
    var body: some View {
        NavigationView {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Date Selector Header
                        DateSelectorHeader(
                            date: viewModel.selectedDate,
                            isLoading: viewModel.isLoading,
                            onDateTap: { showingDatePicker = true },
                            onRefresh: {
                                Task {
                                    await viewModel.refreshSummary()
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo("top", anchor: .top)
                                    }
                                }
                            }
                        )
                        .id("top")
                        
                        // Content
                        if viewModel.isLoading {
                            LoadingView()
                                .padding(.top, 60)
                        } else if let summary = viewModel.summary {
                            EnhancedSummaryContentView(summary: summary)
                                .padding(.top, DesignSystem.Spacing.md)
                        } else if let errorMessage = viewModel.errorMessage {
                            ErrorView(message: errorMessage) {
                                Task {
                                    await viewModel.refreshSummary()
                                }
                            }
                            .padding(.top, 60)
                        } else {
                            EmptyStateView()
                                .padding(.top, 60)
                        }
                    }
                    .padding(.bottom, 85)
                }
            }
            .navigationTitle("Today's AI Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: TimelineDayView(date: viewModel.selectedDate)) {
                        Image(systemName: "clock.fill")
                            .foregroundColor(DesignSystem.Colors.primary)
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                EnhancedDatePickerSheet(selectedDate: $viewModel.selectedDate)
            }
            .onAppear {
                if viewModel.summary == nil && !viewModel.isLoading {
                    Task {
                        await viewModel.loadSummary(for: viewModel.selectedDate)
                    }
                }
            }
            .onChange(of: viewModel.selectedDate) { oldDate, newDate in
                Task {
                    await viewModel.loadSummary(for: newDate)
                }
            }
        }
    }
}

// MARK: - Date Selector Header
struct DateSelectorHeader: View {
    let date: Date
    let isLoading: Bool
    let onDateTap: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onDateTap) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                    Text(date, style: .date)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(DesignSystem.Colors.primary)
            }
            
            Spacer()
            
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
            .disabled(isLoading)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color(.systemBackground))
    }
}

// MARK: - Enhanced Summary Content View
struct EnhancedSummaryContentView: View {
    let summary: EnhancedDailySummaryResponse
    @State private var hasAppeared = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Overview Card - Large Header
            OverviewCard(overview: summary.overview)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
                .animation(.easeOut(duration: 0.4).delay(0.1), value: hasAppeared)
            
            // Section Divider
            if !summary.keyHighlights.isEmpty {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            // Key Highlights
            if !summary.keyHighlights.isEmpty {
                HighlightsSection(highlights: summary.keyHighlights)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(.easeOut(duration: 0.4).delay(0.2), value: hasAppeared)
            }
            
            // Section Divider
            if !summary.potentialIssues.isEmpty {
                Divider()
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            // Potential Issues
            if !summary.potentialIssues.isEmpty {
                IssuesSection(issues: summary.potentialIssues)
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
            
            // Suggestions - Using new animated cards
            if !summary.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.accent)
                        Text("Suggestions")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(Array(summary.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                            EnhancedSuggestionCard(suggestion: suggestion)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            
            // Day Intel Summary (if available)
            if summary.dayIntel.aggregates.totalEvents > 0 {
                DayIntelSummaryCard(dayIntel: summary.dayIntel)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)
                    .opacity(hasAppeared ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.5), value: hasAppeared)
            }
        }
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Overview Card
struct OverviewCard: View {
    let overview: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                Text("Overview")
                    .font(DesignSystem.Typography.title1)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
            }
            
            // Adaptive text with better line spacing for mobile reading
            Text(overview)
                .font(DesignSystem.Typography.body)
                .lineSpacing(8)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Highlights Section
struct HighlightsSection: View {
    let highlights: [HighlightItem]
    
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
                ForEach(highlights) { highlight in
                    HighlightRow(highlight: highlight)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(Color.blue.opacity(0.08))
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Highlight Row
struct HighlightRow: View {
    let highlight: HighlightItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(highlight.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let details = highlight.details, !details.isEmpty {
                        Text(details)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Issues Section
struct IssuesSection: View {
    let issues: [IssueItem]
    
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
                ForEach(issues) { issue in
                    IssueRow(issue: issue)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(Color.orange.opacity(0.08))
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Issue Row
struct IssueRow: View {
    let issue: IssueItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.orange.opacity(0.3))
                    .frame(width: 6, height: 6)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if let details = issue.details, !details.isEmpty {
                        Text(details)
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Suggestions Section
struct EnhancedSuggestionsSection: View {
    let suggestions: [SuggestionItem]
    
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
            
            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    EnhancedSuggestionCard(suggestion: suggestion)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Enhanced Suggestion Card
struct EnhancedSuggestionCard: View {
    let suggestion: SuggestionItem
    
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
            // Time window if available
            if let timeWindow = suggestion.timeWindow,
               let start = timeWindow.start, !start.isEmpty,
               let end = timeWindow.end, !end.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                    
                    if let startDate = Self.iso8601Formatter.date(from: start),
                       let endDate = Self.iso8601Formatter.date(from: end) {
                        Text("\(Self.timeFormatter.string(from: startDate)) - \(Self.timeFormatter.string(from: endDate))")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    } else {
                        Text("\(start) - \(end)")
                            .font(DesignSystem.Typography.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }
            }
            
            // Headline
            Text(suggestion.headline)
                .font(DesignSystem.Typography.body)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            // Details if available
            if let details = suggestion.details, !details.isEmpty {
                Text(details)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(Color.green.opacity(0.08))
        )
    }
}

// MARK: - Day Intel Summary Card
struct DayIntelSummaryCard: View {
    let dayIntel: DayIntel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day Insights")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dayIntel.aggregates.totalEvents)")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("Events")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dayIntel.aggregates.meetingMinutes)")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primary)
                    Text("Minutes")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                if dayIntel.aggregates.hasEarlyStart {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        Text("Early Start")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
                
                if dayIntel.aggregates.hasLateEnd {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        Text("Late End")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

