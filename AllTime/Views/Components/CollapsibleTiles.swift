import SwiftUI

// MARK: - Collapsible Tiles for Today Screen
/// Progressive disclosure versions of key tiles.
/// Each shows minimal info when collapsed, full content when expanded.

// MARK: - Collapsible Primary Recommendation Card
/// Collapsed: icon + short action (1 line)
/// Expanded: full action, reason, consequence, CTA
struct CollapsiblePrimaryRecommendationCard: View {
    let recommendation: PrimaryRecommendation
    let tileId: String
    @ObservedObject var expansionManager: TileExpansionManager
    var onTap: (() -> Void)? = nil

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // COLLAPSED: Icon + action headline
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack(spacing: 12) {
                    // Icon with urgency color
                    Image(systemName: recommendation.displayIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(recommendation.urgencyColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        // Urgency label
                        Text(recommendation.urgencyLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(recommendation.urgencyColor)
                            .textCase(.uppercase)

                        // Short action
                        Text(recommendation.action)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer()

                    // Expand/Collapse indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(TileButtonStyle())

            // EXPANDED: Full details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.vertical, 8)

                    // High confidence indicator
                    if recommendation.isHighConfidence {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10))
                            Text("Clara recommends")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    // Reason
                    if let reason = recommendation.reason, !reason.isEmpty {
                        Text(reason)
                            .font(.system(size: 14))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Consequence warning
                    if let consequence = recommendation.ignoredConsequence, !consequence.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(consequence)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(DesignSystem.Colors.amber)
                    }

                    // CTA Button
                    if onTap != nil {
                        Button(action: { onTap?() }) {
                            Text("Take Action")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(recommendation.urgencyColor)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isExpanded ? recommendation.urgencyColor.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Collapsible Clara Card
/// Collapsed: Clara avatar + "Ready" badge (ultra-minimal)
/// Expanded: Contextual prompts
struct CollapsibleClaraCard: View {
    let prompts: [ClaraPrompt]
    let tileId: String
    @ObservedObject var expansionManager: TileExpansionManager
    var onPromptTap: ((ClaraPrompt) -> Void)? = nil

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    private let claraGradient = LinearGradient(
        colors: [DesignSystem.Colors.violet, DesignSystem.Colors.claraPurpleLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // COLLAPSED: Clara + Ready badge
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack(spacing: 12) {
                    // Clara Avatar (smaller when collapsed)
                    ZStack {
                        Circle()
                            .fill(claraGradient)
                            .frame(width: 36, height: 36)

                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clara")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if !isExpanded {
                            Text("Tap for suggestions")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    Spacer()

                    // Ready indicator
                    HStack(spacing: 4) {
                        Circle()
                            .fill(DesignSystem.Colors.emerald)
                            .frame(width: 6, height: 6)
                        Text("Ready")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.emerald)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.emerald.opacity(0.1))
                    .clipShape(Capsule())

                    // Expand indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(TileButtonStyle())

            // EXPANDED: Prompt suggestions
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()
                        .padding(.top, 8)

                    Text("What can I help with?")
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    // Prompt grid (2 columns)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(prompts.prefix(4), id: \.promptId) { prompt in
                            CollapsibleClaraPromptButton(prompt: prompt) {
                                onPromptTap?(prompt)
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isExpanded ? DesignSystem.Colors.violet.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Collapsible Clara Prompt Button
private struct CollapsibleClaraPromptButton: View {
    let prompt: ClaraPrompt
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 8) {
                Image(systemName: prompt.displayIcon)
                    .font(.system(size: 12))
                    .foregroundColor(prompt.categoryColor)

                Text(prompt.label ?? "Ask")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Spacer()
            }
            .padding(10)
            .background(DesignSystem.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Collapsible Energy Budget Card
/// Collapsed: Energy score circle + capacity label
/// Expanded: Drains, deposits, peak/low windows, recommendations
struct CollapsibleEnergyBudgetCard: View {
    let energyBudget: EnergyBudget
    let tileId: String
    @ObservedObject var expansionManager: TileExpansionManager

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // COLLAPSED: Score circle + label
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack(spacing: 12) {
                    // Compact energy indicator
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.Colors.tertiaryText.opacity(0.2), lineWidth: 3)
                            .frame(width: 36, height: 36)

                        Circle()
                            .trim(from: 0, to: energyBudget.levelPercentage)
                            .stroke(energyBudget.capacityColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 36, height: 36)
                            .rotationEffect(.degrees(-90))

                        Text("\(energyBudget.currentLevel ?? 50)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(energyBudget.capacityLabel ?? "Energy")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if !isExpanded {
                            HStack(spacing: 4) {
                                Image(systemName: energyBudget.trajectoryIcon)
                                    .font(.system(size: 10))
                                Text(energyBudget.trajectoryLabel ?? "")
                                    .font(.caption)
                            }
                            .foregroundColor(energyBudget.trajectoryColor)
                        }
                    }

                    Spacer()

                    // Expand indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(TileButtonStyle())

            // EXPANDED: Full details
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.vertical, 8)

                    // Trajectory detail
                    HStack(spacing: 4) {
                        Image(systemName: energyBudget.trajectoryIcon)
                            .font(.system(size: 12))
                        Text(energyBudget.trajectoryLabel ?? "")
                            .font(.subheadline)
                    }
                    .foregroundColor(energyBudget.trajectoryColor)

                    // Energy drains
                    if let drains = energyBudget.energyDrains, !drains.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ENERGY DRAINS")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)

                            ForEach(drains.prefix(3), id: \.factorId) { factor in
                                CompactEnergyFactorRow(factor: factor)
                            }
                        }
                    }

                    // Energy deposits
                    if let deposits = energyBudget.energyDeposits, !deposits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ENERGY DEPOSITS")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.tertiaryText)

                            ForEach(deposits.prefix(3), id: \.factorId) { factor in
                                CompactEnergyFactorRow(factor: factor)
                            }
                        }
                    }

                    // Peak and low windows (compact)
                    HStack(spacing: 12) {
                        if let peak = energyBudget.peakWindow {
                            CompactWindowBadge(
                                label: "Peak",
                                time: peak.displayLabel,
                                color: DesignSystem.Colors.emerald
                            )
                        }
                        if let low = energyBudget.lowWindow {
                            CompactWindowBadge(
                                label: "Low",
                                time: low.displayLabel,
                                color: DesignSystem.Colors.amber
                            )
                        }
                    }

                    // Recovery recommendation
                    if energyBudget.needsRecovery, let recommendation = energyBudget.recoveryRecommendation {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(DesignSystem.Colors.errorRed)
                            Text(recommendation)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .padding(10)
                        .background(DesignSystem.Colors.errorRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Compact Energy Factor Row
private struct CompactEnergyFactorRow: View {
    let factor: BriefingEnergyFactor

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: factor.displayIcon)
                .font(.system(size: 12))
                .foregroundColor(factor.impactColor)
                .frame(width: 20)

            Text(factor.label ?? "")
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primaryText)
                .lineLimit(1)

            Spacer()

            Text(factor.formattedImpact)
                .font(.caption.weight(.medium))
                .foregroundColor(factor.impactColor)
        }
    }
}

// MARK: - Compact Window Badge
private struct CompactWindowBadge: View {
    let label: String
    let time: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(color)
            Text(time)
                .font(.caption)
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Collapsible Actions Row
/// Collapsed: Two compact cards with icon + count only
/// Expanded: Full subtitles and previews
struct CollapsibleActionsRow: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let isLoading: Bool
    @ObservedObject var expansionManager: TileExpansionManager
    let onSuggestionsTap: () -> Void
    let onTodoTap: () -> Void

    private var suggestionsCount: Int {
        overview?.suggestionsTile.count ?? briefing?.suggestions?.count ?? 0
    }

    private var topSuggestion: String? {
        overview?.suggestionsTile.previewLine ?? briefing?.suggestions?.first?.title
    }

    private var pendingTasks: Int {
        overview?.todoTile.pendingCount ?? 0
    }

    private var overdueTasks: Int {
        overview?.todoTile.overdueCount ?? 0
    }

    private var actionsExpanded: Bool {
        expansionManager.isExpanded(TileExpansionManager.TileId.actions.rawValue)
    }

    private var tasksExpanded: Bool {
        expansionManager.isExpanded(TileExpansionManager.TileId.tasks.rawValue)
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Actions tile
            CollapsibleActionCard(
                tileId: TileExpansionManager.TileId.actions.rawValue,
                icon: "sparkles",
                iconColor: DesignSystem.Colors.amber,
                title: "Actions",
                count: suggestionsCount,
                subtitle: topSuggestion,
                isLoading: isLoading,
                expansionManager: expansionManager,
                onTap: onSuggestionsTap
            )

            // Tasks tile
            CollapsibleActionCard(
                tileId: TileExpansionManager.TileId.tasks.rawValue,
                icon: "checklist",
                iconColor: DesignSystem.Colors.emerald,
                title: "Tasks",
                count: pendingTasks,
                subtitle: overdueTasks > 0 ? "\(overdueTasks) overdue" : nil,
                badgeColor: overdueTasks > 0 ? DesignSystem.Colors.softWarning : nil,
                isLoading: isLoading,
                expansionManager: expansionManager,
                onTap: onTodoTap
            )
        }
    }
}

// MARK: - Collapsible Action Card
private struct CollapsibleActionCard: View {
    let tileId: String
    let icon: String
    let iconColor: Color
    let title: String
    let count: Int
    let subtitle: String?
    var badgeColor: Color? = nil
    let isLoading: Bool
    @ObservedObject var expansionManager: TileExpansionManager
    let onTap: () -> Void

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    var body: some View {
        Button(action: {
            print("🔘 CollapsibleActionCard: Button tapped! tileId=\(tileId), isExpanded=\(isExpanded)")
            // If collapsed, expand first. If expanded, trigger action.
            if isExpanded {
                print("🔘 CollapsibleActionCard: Calling onTap()")
                onTap()
            } else {
                print("🔘 CollapsibleActionCard: Calling toggle(\(tileId))")
                expansionManager.toggle(tileId)
            }
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                if isLoading {
                    skeletonContent
                } else {
                    // Header with icon and count
                    HStack {
                        Image(systemName: icon)
                            .font(.body)
                            .foregroundColor(iconColor.opacity(0.9))

                        Spacer()

                        if count > 0 {
                            Text("\(count)")
                                .font(.title3.weight(.semibold))
                                .foregroundColor(DesignSystem.Colors.primaryText)
                        }

                        // Chevron indicator for expansion state
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }

                    // Title
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    // Subtitle (only when expanded or always show for overdue)
                    if let subtitle = subtitle, (isExpanded || badgeColor != nil) {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(badgeColor ?? DesignSystem.Colors.secondaryText)
                            .lineLimit(isExpanded ? 2 : 1)
                    } else if count == 0 {
                        Text("All clear")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    // Show "Tap to open" hint when expanded
                    if isExpanded {
                        HStack {
                            Spacer()
                            Text("Tap to open")
                                .font(.caption2)
                                .foregroundColor(iconColor)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(iconColor)
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isExpanded ? iconColor.opacity(0.08) : DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(isExpanded ? iconColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isExpanded)
        }
        .buttonStyle(TileButtonStyle())
    }

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 24, height: 24)
                Spacer()
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 24, height: 24)
            }

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(width: 60, height: 14)
        }
    }
}

// MARK: - Collapsible Schedule Section
/// Collapsed: Shows only next upcoming event or "X events today"
/// Expanded: Full event list
struct CollapsibleScheduleSection: View {
    let events: [Event]
    let currentEvent: Event?
    let tileId: String
    @ObservedObject var expansionManager: TileExpansionManager
    var onEventTap: ((Event) -> Void)? = nil

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    private var upcomingEvents: [Event] {
        let now = Date()
        return events.filter { event in
            guard let endDate = event.endDate else { return false }
            return endDate > now
        }
    }

    private var pastEvents: [Event] {
        let now = Date()
        return events.filter { event in
            guard let endDate = event.endDate else { return true }
            return endDate <= now
        }
    }

    private var nextEvent: Event? {
        let now = Date()
        return events.first { event in
            guard let startDate = event.startDate else { return false }
            return startDate > now
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section header
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack {
                    Text("Schedule")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Spacer()

                    Text("\(events.count) event\(events.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.tertiaryText)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Content
            VStack(spacing: 8) {
                if isExpanded {
                    // Show all events
                    ForEach(events.prefix(7)) { event in
                        CompactEventRow(
                            event: event,
                            isCurrentEvent: event.id == currentEvent?.id,
                            isPastEvent: pastEvents.contains { $0.id == event.id }
                        )
                        .onTapGesture { onEventTap?(event) }
                    }

                    if events.count > 7 {
                        Text("+ \(events.count - 7) more")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else {
                    // Collapsed: show current or next event
                    if let current = currentEvent {
                        CompactEventRow(event: current, isCurrentEvent: true, isPastEvent: false)
                            .onTapGesture { onEventTap?(current) }
                    } else if let next = nextEvent {
                        CompactEventRow(event: next, isCurrentEvent: false, isPastEvent: false)
                            .onTapGesture { onEventTap?(next) }
                    } else if let last = events.last {
                        CompactEventRow(event: last, isCurrentEvent: false, isPastEvent: true)
                            .onTapGesture { onEventTap?(last) }
                    }

                    if events.count > 1 {
                        Text("Tap to see all \(events.count) events")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    let manager = TileExpansionManager()

    return ScrollView {
        VStack(spacing: 16) {
            // Mock data would go here for preview
            Text("Collapsible Tiles Preview")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
