import SwiftUI

// MARK: - Life Insights View (Monthly - Visual-First Redesign)

/// Main view for AI-generated life insights over 30 or 60 days.
/// Redesigned for visual scanning - icons, gauges, colors speak before text.
struct LifeInsightsView: View {
    @StateObject private var viewModel = LifeInsightsViewModel()
    @State private var showRegenerateConfirm = false
    @State private var selectedInsightCard: InsightCardType?

    enum InsightCardType: Identifiable {
        case patterns, wins, alerts, recovery, cognitive, future
        var id: Self { self }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Mode Toggle
                modeToggleHeader

                if viewModel.isLoading && !viewModel.hasData {
                    loadingView
                } else if viewModel.hasData {
                    // Hero: Headline + Key Stats
                    heroCard

                    // Quick Glance: Horizontal status pills
                    quickGlanceSection

                    // Insight Tiles: Tappable visual cards
                    insightTilesSection

                    // Focus Areas (simplified)
                    if !viewModel.displayNextWeekFocus.isEmpty {
                        focusSection
                    }

                    // Regenerate
                    regenerateButton

                } else if let error = viewModel.error {
                    errorView(error)
                }

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(DesignSystem.Colors.background)
        .refreshable { await viewModel.refresh() }
        .task {
            async let insightsTask: () = viewModel.loadInsights()
            async let rateLimitTask: () = viewModel.fetchRateLimitStatus()
            _ = await (insightsTask, rateLimitTask)
        }
        .onDisappear { viewModel.cancelPendingRequests() }
        .sheet(item: $selectedInsightCard) { card in
            InsightDetailSheet(cardType: card, viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog("Regenerate Insights", isPresented: $showRegenerateConfirm, titleVisibility: .visible) {
            Button("Regenerate") { Task { await viewModel.regenerateInsights() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Generate fresh insights. \(viewModel.remainingRegenerations) left today.")
        }
    }

    // MARK: - Mode Toggle

    private var modeToggleHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Insights")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(viewModel.selectedMode == .thirtyDay ? "Last 30 days" : "Last 60 days")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }

            Spacer()

            // Compact pill toggle
            HStack(spacing: 4) {
                ForEach(LifeInsightsMode.allCases, id: \.rawValue) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        Task { await viewModel.switchMode(to: mode) }
                    } label: {
                        Text(mode == .thirtyDay ? "30D" : "60D")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(viewModel.selectedMode == mode ? .white : DesignSystem.Colors.tertiaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(viewModel.selectedMode == mode ? DesignSystem.Colors.primary : Color.clear)
                            )
                    }
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(DesignSystem.Colors.cardBackgroundElevated)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
            )
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Headline
            Text(viewModel.displayHeadline)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Metrics row
            if !viewModel.displayKeyMetrics.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(viewModel.displayKeyMetrics.prefix(4).enumerated()), id: \.element.id) { index, metric in
                        metricPill(metric)

                        if index < min(viewModel.displayKeyMetrics.count - 1, 3) {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4F46E5"), Color(hex: "7C3AED")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(hex: "4F46E5").opacity(0.3), radius: 12, y: 6)
        )
    }

    private func metricPill(_ metric: LifeKeyMetric) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: metric.displayIcon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text(metric.value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(metric.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Glance Section

    private var quickGlanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AT A GLANCE")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(0.8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Recovery Status
                    if let debt = viewModel.displayRecoveryDebt {
                        QuickGlancePill(
                            emoji: debt.debtLevel == "critical" ? "🪫" : debt.debtLevel == "elevated" ? "🔋" : "✅",
                            label: "Recovery",
                            value: debt.debtLevel?.capitalized ?? "Good",
                            color: debt.debtColor
                        ) {
                            selectedInsightCard = .recovery
                        }
                    }

                    // Cognitive Status
                    if let forecast = viewModel.displayCognitiveForecast {
                        QuickGlancePill(
                            emoji: forecast.capacityLevel == "impaired" ? "🧠" : forecast.capacityLevel == "reduced" ? "💭" : "✨",
                            label: "Focus",
                            value: forecast.currentCapacity ?? "Normal",
                            color: forecast.capacityColor
                        ) {
                            selectedInsightCard = .cognitive
                        }
                    }

                    // Alerts count
                    let alertCount = viewModel.displayPatternsToWatch.filter { $0.severity == "critical" || $0.severity == "moderate" }.count
                    if alertCount > 0 {
                        QuickGlancePill(
                            emoji: "⚠️",
                            label: "Alerts",
                            value: "\(alertCount)",
                            color: Color(hex: "F59E0B")
                        ) {
                            selectedInsightCard = .alerts
                        }
                    }

                    // Wins count
                    let winsCount = viewModel.displayWhatWentWell.count
                    if winsCount > 0 {
                        QuickGlancePill(
                            emoji: "🎉",
                            label: "Wins",
                            value: "\(winsCount)",
                            color: Color(hex: "10B981")
                        ) {
                            selectedInsightCard = .wins
                        }
                    }

                    // Future risk
                    if let future = viewModel.displayFutureImpact {
                        QuickGlancePill(
                            emoji: future.riskLevel == "high" ? "🔥" : future.riskLevel == "moderate" ? "📊" : "👍",
                            label: "Outlook",
                            value: future.riskLevel?.capitalized ?? "Good",
                            color: future.riskColor
                        ) {
                            selectedInsightCard = .future
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Insight Tiles Section

    private var insightTilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INSIGHTS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(0.8)

            VStack(spacing: 10) {
                // Patterns - main insights
                if !viewModel.displayPatterns.isEmpty {
                    InsightTile(
                        icon: "sparkles",
                        title: "Life Patterns",
                        subtitle: "\(viewModel.displayPatterns.count) patterns discovered",
                        accentColor: Color(hex: "8B5CF6"),
                        items: viewModel.displayPatterns
                    ) {
                        selectedInsightCard = .patterns
                    }
                }

                // Patterns to Watch
                if !viewModel.displayPatternsToWatch.isEmpty {
                    let criticalCount = viewModel.displayPatternsToWatch.filter { $0.severity == "critical" }.count
                    InsightTile(
                        icon: "eye.fill",
                        title: "Watch These",
                        subtitle: criticalCount > 0 ? "\(criticalCount) need attention" : "\(viewModel.displayPatternsToWatch.count) to monitor",
                        accentColor: criticalCount > 0 ? Color(hex: "EF4444") : Color(hex: "F59E0B"),
                        items: viewModel.displayPatternsToWatch
                    ) {
                        selectedInsightCard = .alerts
                    }
                }

                // What Went Well
                if !viewModel.displayWhatWentWell.isEmpty {
                    InsightTile(
                        icon: "checkmark.circle.fill",
                        title: "What Went Well",
                        subtitle: "\(viewModel.displayWhatWentWell.count) highlights this period",
                        accentColor: Color(hex: "10B981"),
                        items: viewModel.displayWhatWentWell
                    ) {
                        selectedInsightCard = .wins
                    }
                }
            }
        }
    }

    // MARK: - Focus Section

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FOCUS AREAS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
                .tracking(0.8)

            VStack(spacing: 8) {
                ForEach(viewModel.displayNextWeekFocus.prefix(3)) { action in
                    FocusItemRow(action: action)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
            )
        }
    }

    // MARK: - Regenerate Button

    private var regenerateButton: some View {
        Button { showRegenerateConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("Regenerate Insights")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Text("\(viewModel.remainingRegenerations) left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(viewModel.canRegenerate ? DesignSystem.Colors.primary.opacity(0.6) : DesignSystem.Colors.tertiaryText)
            }
            .foregroundColor(viewModel.canRegenerate ? DesignSystem.Colors.primary : DesignSystem.Colors.disabledText)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(viewModel.canRegenerate ? DesignSystem.Colors.primary.opacity(0.08) : DesignSystem.Colors.cardBackgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.canRegenerate ? DesignSystem.Colors.primary.opacity(0.2) : Color.clear, lineWidth: 1)
            )
        }
        .disabled(!viewModel.canRegenerate)
    }

    // MARK: - Loading & Error

    private var loadingView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
                    .frame(width: 64, height: 64)

                ProgressView()
                    .scaleEffect(1.1)
                    .tint(DesignSystem.Colors.primary)
            }

            VStack(spacing: 4) {
                Text("Analyzing your month")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text("This may take a moment...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "EF4444").opacity(0.1))
                    .frame(width: 64, height: 64)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "EF4444"))
            }

            VStack(spacing: 4) {
                Text("Unable to load insights")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button { Task { await viewModel.loadInsights() } } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Try Again")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(DesignSystem.Colors.primary)
                        .shadow(color: DesignSystem.Colors.primary.opacity(0.3), radius: 8, y: 4)
                )
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Quick Glance Pill

struct QuickGlancePill: View {
    let emoji: String
    let label: String
    let value: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 1) {
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .tracking(0.3)

                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Insight Tile (Tappable Card)

struct InsightTile: View {
    let icon: String
    let title: String
    let subtitle: String
    let accentColor: Color
    let items: [LifeInsightItem]
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(accentColor)
                }

                // Title & Subtitle
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                Spacer()

                // Preview dots (severity indicators)
                HStack(spacing: 5) {
                    ForEach(items.prefix(4)) { item in
                        Circle()
                            .fill(item.severityColor)
                            .frame(width: 7, height: 7)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: Color.black.opacity(0.03), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(accentColor.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Focus Item Row

struct FocusItemRow: View {
    let action: LifeActionItem

    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            ZStack {
                Circle()
                    .fill(action.priorityColor.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: action.displayIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(action.priorityColor)
            }

            Text(action.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(2)

            Spacer()

            if action.priority == "high" {
                Text("Priority")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(action.priorityColor)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Insight Detail Sheet

struct InsightDetailSheet: View {
    let cardType: LifeInsightsView.InsightCardType
    @ObservedObject var viewModel: LifeInsightsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch cardType {
                    case .patterns:
                        patternsDetail
                    case .wins:
                        winsDetail
                    case .alerts:
                        alertsDetail
                    case .recovery:
                        recoveryDetail
                    case .cognitive:
                        cognitiveDetail
                    case .future:
                        futureDetail
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
        }
    }

    private var sheetTitle: String {
        switch cardType {
        case .patterns: return "Life Patterns"
        case .wins: return "What Went Well"
        case .alerts: return "Watch These"
        case .recovery: return "Recovery Status"
        case .cognitive: return "Cognitive Capacity"
        case .future: return "Future Outlook"
        }
    }

    // MARK: - Patterns Detail

    private var patternsDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.displayPatterns) { item in
                DetailInsightCard(item: item)
            }
        }
    }

    // MARK: - Wins Detail

    private var winsDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.displayWhatWentWell) { item in
                HStack(alignment: .top, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "10B981").opacity(0.15))
                            .frame(width: 36, height: 36)

                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "10B981"))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if let detail = item.detail {
                            Text(detail)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(hex: "10B981").opacity(0.06))
                )
            }
        }
    }

    // MARK: - Alerts Detail

    private var alertsDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(viewModel.displayPatternsToWatch) { item in
                DetailInsightCard(item: item)
            }
        }
    }

    // MARK: - Recovery Detail

    private var recoveryDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let debt = viewModel.displayRecoveryDebt {
                // Visual gauge card
                VStack(spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Sleep Debt")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(DesignSystem.Colors.secondaryText)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(debt.formattedDebtHours)
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundColor(debt.debtColor)

                                if let level = debt.debtLevel {
                                    Text(level.capitalized)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(debt.debtColor))
                                }
                            }
                        }

                        Spacer()

                        Image(systemName: debt.debtIcon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(debt.debtColor.opacity(0.6))
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(debt.debtColor.opacity(0.15))
                                .frame(height: 10)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(debt.debtColor)
                                .frame(width: min(geo.size.width * CGFloat((debt.debtHours ?? 0) / 10), geo.size.width), height: 10)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(debt.debtColor.opacity(0.06))
                )

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    if let detail = debt.detail {
                        InsightDetailRow(icon: "info.circle.fill", text: detail, color: DesignSystem.Colors.secondaryText)
                    }

                    if let impact = debt.performanceImpact {
                        InsightDetailRow(icon: "brain.head.profile", text: impact, color: debt.debtColor)
                    }

                    if let payback = debt.paybackEstimate {
                        InsightDetailRow(icon: "arrow.counterclockwise", text: payback, color: Color(hex: "10B981"))
                    }
                }
            }
        }
    }

    // MARK: - Cognitive Detail

    private var cognitiveDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let forecast = viewModel.displayCognitiveForecast {
                // Capacity gauge card
                HStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.Colors.calmBorder, lineWidth: 10)
                            .frame(width: 90, height: 90)

                        if let percentage = forecast.capacityPercentage {
                            Circle()
                                .trim(from: 0, to: CGFloat(percentage) / 100)
                                .stroke(forecast.capacityColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 90, height: 90)
                                .rotationEffect(.degrees(-90))
                        }

                        VStack(spacing: 0) {
                            Text(forecast.currentCapacity ?? "—")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(forecast.capacityColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cognitive Capacity")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(DesignSystem.Colors.secondaryText)

                        if let level = forecast.capacityLevel {
                            Text(level.capitalized)
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(forecast.capacityColor)
                        }
                    }

                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(forecast.capacityColor.opacity(0.06))
                )

                // Details
                VStack(alignment: .leading, spacing: 12) {
                    if let peak = forecast.peakHoursToday {
                        InsightDetailRow(icon: "sun.max.fill", text: "Best for deep work: \(peak)", color: Color(hex: "10B981"))
                    }

                    if let avoid = forecast.avoidComplexWork {
                        InsightDetailRow(icon: "exclamationmark.triangle.fill", text: "Avoid decisions: \(avoid)", color: Color(hex: "F59E0B"))
                    }

                    if let decision = forecast.decisionQuality {
                        InsightDetailRow(icon: "hand.raised.fill", text: decision, color: Color(hex: "EF4444"))
                    }

                    if let factors = forecast.contributingFactors, !factors.isEmpty {
                        HStack(spacing: 8) {
                            Text("Factors:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                            Text(factors.joined(separator: " · "))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    if let prescription = forecast.prescription {
                        InsightDetailRow(icon: "arrow.right.circle.fill", text: prescription, color: Color(hex: "10B981"))
                    }
                }
            }
        }
    }

    // MARK: - Future Detail

    private var futureDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let impact = viewModel.displayFutureImpact {
                // Risk header card
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(impact.riskColor.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: impact.riskIcon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(impact.riskColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        if let level = impact.riskLevel {
                            Text("\(level.capitalized) Risk")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(impact.riskColor)
                        }
                        if let headline = impact.headline {
                            Text(headline)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineSpacing(2)
                        }
                    }

                    Spacer()
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(impact.riskColor.opacity(0.06))
                )

                // Predictions
                VStack(alignment: .leading, spacing: 12) {
                    if let tomorrow = impact.tomorrowPrediction {
                        InsightPredictionRow(label: "Tomorrow", text: tomorrow, icon: "sunrise.fill", color: Color(hex: "F59E0B"))
                    }

                    if let week = impact.thisWeekOutlook {
                        InsightPredictionRow(label: "This Week", text: week, icon: "calendar", color: Color(hex: "3B82F6"))
                    }

                    if let riskDay = impact.highestRiskDay {
                        InsightDetailRow(icon: "exclamationmark.triangle.fill", text: "Highest risk: \(riskDay)", color: impact.riskColor)
                    }

                    if let recovery = impact.recoveryNeeded {
                        InsightDetailRow(icon: "arrow.counterclockwise.circle.fill", text: recovery, color: Color(hex: "10B981"))
                    }
                }
            }
        }
    }
}

// MARK: - Detail Insight Card

struct DetailInsightCard: View {
    let item: LifeInsightItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Circle()
                    .fill(item.severityColor)
                    .frame(width: 10, height: 10)

                Text(item.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                if let severity = item.severity {
                    Text(severity.capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(item.severityColor))
                }
            }

            // Detail
            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineSpacing(3)
            }

            // Baseline
            if let baseline = item.vsBaseline {
                Text(baseline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(hex: "3B82F6"))
            }

            // Consequence
            if let consequence = item.consequence {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "F59E0B"))
                        .padding(.top, 2)

                    Text(consequence)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineSpacing(2)
                }
            }

            // Prescription
            if let prescription = item.prescription {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "10B981"))
                        .padding(.top, 2)

                    Text(prescription)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "10B981"))
                        .lineSpacing(2)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(item.severityColor.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(item.severityColor.opacity(0.12), lineWidth: 1)
        )
    }
}

// MARK: - Insight Detail Row

struct InsightDetailRow: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineSpacing(3)
        }
    }
}

// MARK: - Insight Prediction Row

struct InsightPredictionRow: View {
    let label: String
    let text: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(color)
                    .tracking(0.5)
            }

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.06))
        )
    }
}
