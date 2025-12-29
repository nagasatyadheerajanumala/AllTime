import SwiftUI

// MARK: - Life Insights View (Monthly - Unified with Weekly Structure)

/// Main view for AI-generated life insights over 30 or 60 days.
/// Structure matches WeeklyInsightsView for consistency.
struct LifeInsightsView: View {
    @StateObject private var viewModel = LifeInsightsViewModel()
    @State private var expandedRecap = true
    @State private var expandedNextMonth = true
    @State private var showRegenerateConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Mode Toggle Header (equivalent to Week Picker)
                modeToggleHeader

                if viewModel.isLoading && !viewModel.hasData {
                    loadingView
                } else if viewModel.hasData {
                    // Hero Summary Card with Key Metrics (matches Weekly)
                    heroSummaryCard

                    // Your Month Section (matches Weekly's "Your Week")
                    recapSection

                    // Looking Ahead Section (matches Weekly)
                    lookingAheadSection

                    // Regenerate Button (Monthly-specific for AI)
                    regenerateButton

                } else if let error = viewModel.error {
                    errorView(error)
                }

                Spacer(minLength: DesignSystem.Spacing.xl)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenMargin)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.background)
        .refreshable {
            await viewModel.refresh()
        }
        .task {
            async let insightsTask: () = viewModel.loadInsights()
            async let rateLimitTask: () = viewModel.fetchRateLimitStatus()
            _ = await (insightsTask, rateLimitTask)
        }
        .onDisappear {
            viewModel.cancelPendingRequests()
        }
        .confirmationDialog(
            "Regenerate Insights",
            isPresented: $showRegenerateConfirm,
            titleVisibility: .visible
        ) {
            Button("Regenerate") {
                Task { await viewModel.regenerateInsights() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will use AI to generate fresh insights based on your latest calendar data. You have \(viewModel.remainingRegenerations) regenerations left today.")
        }
    }

    // MARK: - Mode Toggle Header (Like Week Picker)

    private var modeToggleHeader: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Monthly Summary")
                .font(.title2.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            // Mode Picker
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(LifeInsightsMode.allCases, id: \.rawValue) { mode in
                    modeButton(mode)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    private func modeButton(_ mode: LifeInsightsMode) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await viewModel.switchMode(to: mode) }
        } label: {
            VStack(spacing: 4) {
                Text(mode.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(mode.description)
                    .font(.caption2)
            }
            .foregroundColor(viewModel.selectedMode == mode ? .white : DesignSystem.Colors.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(viewModel.selectedMode == mode ?
                          LinearGradient(colors: [DesignSystem.Colors.primary, DesignSystem.Colors.primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing) :
                          LinearGradient(colors: [DesignSystem.Colors.cardBackgroundElevated, DesignSystem.Colors.cardBackgroundElevated], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(viewModel.selectedMode == mode ? Color.clear : DesignSystem.Colors.calmBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Hero Summary Card (Matches Weekly - Headline + Metrics Grid)

    private var heroSummaryCard: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Headline
            Text(viewModel.displayHeadline)
                .font(.title3.weight(.semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Key Metrics Grid (same as Weekly)
            if !viewModel.displayKeyMetrics.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(viewModel.displayKeyMetrics.prefix(4)) { metric in
                        heroMetricCard(metric)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "1E1B4B"), Color(hex: "312E81")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func heroMetricCard(_ metric: LifeKeyMetric) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(metric.displayColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                Image(systemName: metric.displayIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(metric.displayColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(metric.value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    if let trendIcon = metric.trendIcon {
                        Image(systemName: trendIcon)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(metric.trend == "up" ? Color(hex: "10B981") : metric.trend == "down" ? Color(hex: "EF4444") : .white.opacity(0.6))
                    }
                }
                Text(metric.label)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.cardBackground)
                    .frame(width: 60, height: 60)
                ProgressView()
                    .scaleEffect(1.2)
            }
            Text("Analyzing your month...")
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.softCritical.opacity(0.1))
                    .frame(width: 64, height: 64)
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(DesignSystem.Colors.softCritical)
            }

            Text("Unable to load insights")
                .font(.headline)
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(message)
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: { Task { await viewModel.loadInsights() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Recap Section (Matches Weekly's "Your Week")

    private var recapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expandedRecap.toggle() } }) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.calmAccent.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.calmAccent)
                        }

                        Text("Your Month")
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Spacer()

                    Image(systemName: expandedRecap ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(DesignSystem.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            if expandedRecap {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Life Patterns (like Weekly's main insights)
                    if !viewModel.displayPatterns.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Life Patterns", systemImage: "sparkles")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primary)

                            ForEach(viewModel.displayPatterns.prefix(3)) { item in
                                insightRow(
                                    icon: item.displayIcon,
                                    title: item.title,
                                    detail: item.detail,
                                    color: item.sentimentColor
                                )
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.primary.opacity(0.05))
                        )
                    }

                    // Patterns to Watch (like Weekly's "Patterns to Watch")
                    if !viewModel.displayPatternsToWatch.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Patterns to Watch", systemImage: "eye")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.neutralBlue)

                            ForEach(viewModel.displayPatternsToWatch.prefix(3)) { item in
                                insightRow(
                                    icon: "circle.fill",
                                    title: item.title,
                                    detail: item.detail,
                                    color: DesignSystem.Colors.neutralBlue
                                )
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.neutralBlue.opacity(0.05))
                        )
                    }

                    // What Went Well (like Weekly's "What Went Well")
                    if !viewModel.displayWhatWentWell.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("What Went Well", systemImage: "checkmark.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.success)

                            ForEach(viewModel.displayWhatWentWell.prefix(2)) { item in
                                insightRow(
                                    icon: "checkmark",
                                    title: item.title,
                                    detail: item.detail,
                                    color: DesignSystem.Colors.success
                                )
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.success.opacity(0.05))
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Looking Ahead Section (Matches Weekly)

    private var lookingAheadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { expandedNextMonth.toggle() } }) {
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.success.opacity(0.15))
                                .frame(width: 32, height: 32)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.success)
                        }

                        Text("Looking Ahead")
                            .font(.headline)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    Spacer()

                    Image(systemName: expandedNextMonth ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(DesignSystem.Spacing.md)
            }
            .buttonStyle(PlainButtonStyle())

            if expandedNextMonth {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Focus Areas (like Weekly's priorities)
                    if !viewModel.displayNextWeekFocus.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Label("Focus Areas", systemImage: "target")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.success)

                            ForEach(viewModel.displayNextWeekFocus.prefix(3)) { action in
                                priorityRow(action)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.success.opacity(0.05))
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
                )
        )
    }

    // MARK: - Regenerate Button (Monthly-specific)

    private var regenerateButton: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                showRegenerateConfirm = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.body.weight(.medium))
                    Text("Regenerate Insights")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundColor(viewModel.canRegenerate ? DesignSystem.Colors.primary : DesignSystem.Colors.disabledText)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(viewModel.canRegenerate ? DesignSystem.Colors.primary.opacity(0.1) : DesignSystem.Colors.cardBackgroundElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(viewModel.canRegenerate ? DesignSystem.Colors.primary.opacity(0.3) : DesignSystem.Colors.calmBorder, lineWidth: 1)
                        )
                )
            }
            .disabled(!viewModel.canRegenerate)

            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text("\(viewModel.remainingRegenerations) regenerations remaining today")
                    .font(.caption)
            }
            .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
    }

    // MARK: - Helper Views (Same as Weekly)

    private func insightRow(icon: String, title: String, detail: String?, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 6))
                .foregroundColor(color)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                if let detail = detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func priorityRow(_ action: LifeActionItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.success.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: action.displayIcon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.success)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(action.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if action.priority == "high" {
                        Text("Priority")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(action.priorityColor)
                            )
                    }
                }

                if let detail = action.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    LifeInsightsView()
}
