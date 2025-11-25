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
                        if summaryViewModel.isLoading {
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
                // Load summary when view appears (if not already loaded)
                if summaryViewModel.summary == nil && !summaryViewModel.isLoading {
                    Task {
                        await summaryViewModel.loadSummary(for: summaryViewModel.selectedDate)
                    }
                }
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
            .background(Color(.systemGroupedBackground))
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
            
            // Metadata Footer
            MetadataFooter(summary: summary)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .opacity(hasAppeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: hasAppeared)
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
                    .fill(Color.blue.opacity(0.08))
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
                    .fill(Color.orange.opacity(0.08))
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
            
            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
    }
}

// MARK: - Metadata Footer
struct MetadataFooter: View {
    let summary: DailyAISummaryResponse
    
    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 12))
                Text("\(summary.totalEvents) event\(summary.totalEvents == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.caption)
            }
            .foregroundColor(DesignSystem.Colors.secondaryText)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                Text(summary.model)
                    .font(DesignSystem.Typography.caption)
            }
            .foregroundColor(DesignSystem.Colors.secondaryText)
        }
    }
}

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
            
            if let reason = suggestion.reason, !reason.isEmpty {
                Text(reason)
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
