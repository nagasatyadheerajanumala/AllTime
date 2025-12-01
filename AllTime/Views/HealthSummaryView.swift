import SwiftUI

struct HealthSummaryView: View {
    @StateObject private var viewModel = HealthSummaryViewModel()
    @State private var showingGoals = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Official Chrona Dark Theme - Pure Black Background
                DesignSystem.Colors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.summary == nil {
                    // Initial loading
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading health summary...")
                            .font(DesignSystem.Typography.subheadline)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                } else if let error = viewModel.errorMessage {
                    // Error state
                    HealthSummaryErrorView(
                        message: error,
                        onRetry: {
                            Task {
                                await viewModel.retry()
                            }
                        }
                    )
                } else if viewModel.summary != nil || viewModel.advancedSummary != nil {
                    // Success state - show either legacy or advanced format
                    ScrollView {
                        VStack(spacing: 20) {
                            // NEW: Advanced Summary Section (if available)
                            if let advanced = viewModel.advancedSummary {
                                AdvancedSummarySection(
                                    thisWeek: advanced.thisWeek,
                                    nextWeek: advanced.nextWeek
                                )
                                .padding(.horizontal)
                                .padding(.top, 8)
                            }
                            
                            // Legacy Summary Header (if available)
                            if let summary = viewModel.summary {
                                SummaryHeaderView(
                                    summary: summary,
                                    expiresAt: viewModel.expiresAt
                                )
                                .padding(.horizontal)
                                .padding(.top, viewModel.advancedSummary == nil ? 8 : 0)
                            }
                            
                            // NEW: Patterns Section
                            if !viewModel.patterns.isEmpty {
                                PatternsSection(patterns: viewModel.patterns)
                                    .padding(.horizontal)
                            }
                            
                            // NEW: Event-Specific Advice Section
                            if !viewModel.eventSpecificAdvice.isEmpty {
                                EventSpecificAdviceSection(advice: viewModel.eventSpecificAdvice)
                                    .padding(.horizontal)
                            }
                            
                            // NEW: Health Suggestions Section (simplified format)
                            if !viewModel.healthSuggestions.isEmpty {
                                HealthSuggestionsSection(suggestions: viewModel.healthSuggestions)
                                    .padding(.horizontal)
                            }
                            
                            // Legacy Suggestions Section (if available)
                            if let summary = viewModel.summary, !summary.suggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("AI Suggestions")
                                            .font(DesignSystem.Typography.title3)
                                            .fontWeight(.bold)
                                            .foregroundColor(DesignSystem.Colors.primaryText)
                                        
                                        Spacer()
                                        
                                        Text("\(summary.suggestions.count)")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.secondaryText)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                Capsule()
                                                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                                            )
                                    }
                                    .padding(.horizontal)
                                    
                                    ForEach(summary.suggestions) { suggestion in
                                        SuggestionCardView(suggestion: suggestion)
                                            .padding(.horizontal)
                                    }
                                }
                                .padding(.top, 8)
                            }
                            
                            // Health Goals section (if goals exist)
                            if let goals = viewModel.goals {
                                HealthGoalsSectionView(
                                    goals: goals,
                                    suggestions: viewModel.summary?.suggestions.filter { suggestion in
                                        suggestion.actionable
                                    } ?? []
                                )
                                .padding(.horizontal)
                            }
                            
                            // Empty state if no suggestions at all
                            if viewModel.summary?.suggestions.isEmpty != false &&
                               viewModel.healthSuggestions.isEmpty &&
                               viewModel.eventSpecificAdvice.isEmpty {
                                EmptySuggestionsView()
                                    .padding(.horizontal)
                                    .padding(.top, 32)
                            }
                        }
                        .padding(.vertical)
                    }
                    .refreshable {
                        await viewModel.refreshSummary()
                    }
                } else {
                    // No summary - generate state
                    EmptySummaryView(
                        onGenerate: {
                            Task {
                                await viewModel.generateSummary()
                            }
                        },
                        isGenerating: viewModel.isGenerating
                    )
                }
            }
            .navigationTitle("Health Summary")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        // Refresh button
                        Button(action: {
                            Task {
                                await viewModel.refreshSummary()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                        .disabled(viewModel.isLoading || viewModel.isGenerating)
                        
                        // Goals button
                        Button(action: {
                            showingGoals = true
                        }) {
                            Image(systemName: "target")
                                .foregroundColor(DesignSystem.Colors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingGoals) {
                HealthGoalsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HealthGoalsUpdated"))) { _ in
                // Reload goals when updated
                Task {
                    await viewModel.loadGoals()
                    await viewModel.generateSummary()
                }
            }
            .onAppear {
                // ALWAYS try to load from cache first (even if summary exists in memory)
                // This ensures we show cached data immediately after tab switches
                // View models are recreated on tab switches, so we need to reload from cache
                Task {
                    await viewModel.loadSummary(forceRefresh: false)
                }
            }
            .refreshable {
                // User explicitly pulled to refresh - force refresh
                await viewModel.loadSummary(forceRefresh: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HealthGoalsUpdated"))) { _ in
                // Regenerate suggestions when goals are updated
                print("📢 HealthSummaryView: Received HealthGoalsUpdated notification, regenerating suggestions...")
                Task {
                    // Reload goals first to get latest values
                    await viewModel.loadGoals()
                    // Then generate new summary with updated goals
                    await viewModel.generateSummary()
                }
            }
        }
    }
}

// MARK: - Empty Summary View

struct EmptySummaryView: View {
    let onGenerate: () -> Void
    let isGenerating: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.primary)
            
            VStack(spacing: 8) {
                Text("No Health Summary")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Text("Generate AI-powered health insights and personalized suggestions based on your activity data.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            Button(action: onGenerate) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primaryText))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "Generating..." : "Generate Summary")
                        .font(DesignSystem.Typography.bodyBold)
                }
                .foregroundColor(DesignSystem.Colors.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(DesignSystem.Colors.primary)
                .cornerRadius(DesignSystem.CornerRadius.button)
                .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .disabled(isGenerating)
            
            if isGenerating {
                Text("This may take 5-10 seconds...")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .padding()
    }
}

// MARK: - Empty Suggestions View

struct EmptySuggestionsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.success)
            
            Text("No suggestions at this time")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

// MARK: - Error View

struct HealthSummaryErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.warning)
            
            Text("Error")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            Text(message)
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button("Retry", action: onRetry)
                .chronaPrimaryButton()
        }
        .padding()
    }
}

// MARK: - Advanced Summary UI Components

struct AdvancedSummarySection: View {
    let thisWeek: String
    let nextWeek: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Health Summary")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("This Week")
                            .font(DesignSystem.Typography.sectionHeader)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    
                    Text(thisWeek)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineSpacing(4)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text("Next Week")
                            .font(DesignSystem.Typography.sectionHeader)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                    
                    Text(nextWeek)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineSpacing(4)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
    }
}

struct PatternsSection: View {
    let patterns: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("Detected Patterns")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text("\(patterns.count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(patterns, id: \.self) { pattern in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .padding(.top, 2)
                        
                        Text(pattern)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(4)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }
}

struct EventSpecificAdviceSection: View {
    let advice: [EventAdvice]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("Event-Specific Advice")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text("\(advice.count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
            }
            
            VStack(spacing: 12) {
                ForEach(advice) { item in
                    EventAdviceCard(advice: item)
                }
            }
        }
    }
}

struct EventAdviceCard: View {
    let advice: EventAdvice
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(advice.eventTitle)
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text(advice.date)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                    
                    Text(advice.issue)
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.primary)
                        .padding(.top, 2)
                    
                    Text(advice.suggestion)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
        )
    }
}

struct HealthSuggestionsSection: View {
    let suggestions: [HealthSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)
                Text("Health Suggestions")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                Text("\(suggestions.count)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.primary.opacity(0.1))
                    )
            }
            
            VStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: iconForMetric(suggestion.metric))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(width: 20)
                            .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.metric.capitalized)
                                .font(DesignSystem.Typography.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.primaryText)
                            
                            Text(suggestion.description)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineSpacing(4)
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
            }
        }
    }
    
    private func iconForMetric(_ metric: String) -> String {
        switch metric.lowercased() {
        case "sleep": return "bed.double.fill"
        case "active_energy", "activeenergy": return "flame.fill"
        case "steps": return "figure.walk"
        case "hrv": return "waveform.path.ecg"
        case "resting_heart_rate", "restingheartrate": return "heart.fill"
        case "active_minutes", "activeminutes": return "clock.fill"
        default: return "heart.text.square.fill"
        }
    }
}

#Preview {
    HealthSummaryView()
}

