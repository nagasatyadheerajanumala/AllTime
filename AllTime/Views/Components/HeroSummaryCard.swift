import SwiftUI

// MARK: - Hero Summary Card (Decision Engine)
/// The heart of Clara's decision engine.
///
/// Philosophy:
/// - Clara exists to prevent bad weeks before they happen.
/// - Time is not neutral. A meeting-free day can still be draining.
/// - Retrospective insight is table stakes. Clara forecasts.
/// - Clara is opinionated. It makes recommendations, not suggestions.
/// - The unit of value is the week.
///
/// This card is NOT a status page. It is a decision surface.
struct HeroSummaryCard: View {
    let overview: TodayOverviewResponse?
    let briefing: DailyBriefingResponse?
    let driftStatus: WeekDriftStatus?
    let isLoading: Bool
    let onTap: () -> Void
    let onInterventionTap: (DriftIntervention) -> Void

    // MARK: - Derived Properties

    /// The dominant narrative - opinionated, not observational
    private var headline: String {
        if let drift = driftStatus {
            return drift.headline
        }
        // Fallback to old style if drift not available
        return overview?.summaryTile.greeting ?? briefing?.greeting ?? "Good day"
    }

    /// Supporting context - opportunity + risk framing
    private var subheadline: String {
        if let drift = driftStatus {
            return drift.subheadline
        }
        return overview?.summaryTile.previewLine ?? briefing?.summaryLine ?? ""
    }

    /// The severity determines the card's visual treatment
    private var severity: DriftSeverity {
        guard let drift = driftStatus else { return .onTrack }
        return DriftSeverity(rawValue: drift.severity) ?? .onTrack
    }

    /// The ONE non-negotiable recommendation
    private var primaryIntervention: DriftIntervention? {
        driftStatus?.interventions.first
    }

    /// Week projection - what happens if nothing changes
    private var weekProjection: String? {
        guard severity != .onTrack, let drift = driftStatus else { return nil }
        return drift.weekProjection
    }

    // MARK: - Body

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if isLoading && driftStatus == nil && overview == nil {
                    skeletonContent
                } else {
                    // 1. Dominant Narrative (Opinionated)
                    narrativeSection

                    // 2. Risk Signal (if drifting)
                    if let projection = weekProjection {
                        riskSignal(projection)
                    }

                    // 3. ONE Non-Negotiable Recommendation
                    if let intervention = primaryIntervention {
                        interventionSection(intervention)
                    }

                    Spacer(minLength: DesignSystem.Spacing.xs)

                    // 4. Contextual Clara Prompt
                    claraPromptSection
                }
            }
            .heroCard(severity: severity)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Narrative Section

    private var narrativeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Drift indicator + Day
            HStack(spacing: 8) {
                // Severity indicator
                HStack(spacing: 4) {
                    Image(systemName: severity.icon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(severity.displayName)
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(Color(hex: severity.color))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(hex: severity.color).opacity(0.15))
                )

                Spacer()

                // Day indicator
                Text(dayOfWeekLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Main headline - the opinionated statement
            Text(headline)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Subheadline - supporting context
            if !subheadline.isEmpty {
                Text(subheadline)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Risk Signal

    private func riskSignal(_ projection: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: severity.color))

            Text(projection)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: severity.color).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: severity.color).opacity(0.2), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Intervention Section (ONE Recommendation)

    private func interventionSection(_ intervention: DriftIntervention) -> some View {
        Button(action: {
            HapticManager.shared.mediumTap()
            onInterventionTap(intervention)
        }) {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: intervention.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Action + Detail
                VStack(alignment: .leading, spacing: 2) {
                    Text(intervention.action)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(intervention.detail)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }

                Spacer()

                // Action indicator
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Clara Prompt (Contextual)

    private var claraPromptSection: some View {
        let prompt = contextualClaraPrompt

        return HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.caption2)
                .foregroundColor(Color(hex: "A855F7"))

            Text(prompt)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top, 4)
    }

    /// Contextual prompts that teach users how to think WITH Clara
    private var contextualClaraPrompt: String {
        switch severity {
        case .onTrack:
            return "Ask Clara what to protect today"
        case .watch:
            return "Ask Clara what's at risk this week"
        case .drifting:
            return "Ask Clara what to move or drop"
        case .critical:
            return "Ask Clara for emergency triage"
        }
    }

    // MARK: - Day Label

    private var dayOfWeekLabel: String {
        guard let drift = driftStatus else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: Date())
        }
        return "Day \(drift.dayOfWeek) of 7"
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Severity badge skeleton
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.1))
                .frame(width: 80, height: 24)

            // Headline skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(height: 24)

            // Subheadline skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(width: 280, height: 16)

            // Intervention skeleton
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.06))
                .frame(height: 56)

            Spacer(minLength: DesignSystem.Spacing.sm)

            // Clara prompt skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.04))
                .frame(width: 200, height: 14)
        }
        .frame(minHeight: 180)
    }
}

// MARK: - Hero Card Modifier (Updated with Severity)

extension View {
    func heroCard(severity: DriftSeverity = .onTrack) -> some View {
        self
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 180)
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "1E1E2E"),
                            Color(hex: "151520")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    // Severity accent glow
                    if severity != .onTrack {
                        RadialGradient(
                            colors: [
                                Color(hex: severity.color).opacity(0.15),
                                Color.clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 200
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl)
                    .stroke(
                        severity != .onTrack
                            ? Color(hex: severity.color).opacity(0.3)
                            : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Backward Compatibility Initializer

extension HeroSummaryCard {
    /// Backward-compatible initializer without drift status
    init(
        overview: TodayOverviewResponse?,
        briefing: DailyBriefingResponse?,
        isLoading: Bool,
        onTap: @escaping () -> Void
    ) {
        self.overview = overview
        self.briefing = briefing
        self.driftStatus = nil
        self.isLoading = isLoading
        self.onTap = onTap
        self.onInterventionTap = { _ in }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        // On track
        HeroSummaryCard(
            overview: nil,
            briefing: nil,
            driftStatus: WeekDriftStatus(
                driftScore: 15,
                severity: "on_track",
                severityLabel: "On Track",
                dayOfWeek: 2,
                dayLabel: "TUESDAY",
                headline: "This week is on course.",
                subheadline: "Early week looks manageable. Protect what's working.",
                signals: DriftSignals(
                    meetingHoursThisWeek: 8,
                    meetingHoursRemaining: 6,
                    meetingCount: 12,
                    backToBackCount: 2,
                    eveningEncroachment: 0,
                    baselineMeetingHoursPerWeek: 12,
                    varianceFromBaseline: -33,
                    taskDeferrals: 1,
                    overdueCount: 0,
                    sleepDebtHours: 0,
                    activityGapPercent: 10
                ),
                interventions: [
                    DriftIntervention(
                        id: "protect",
                        action: "Keep it protected",
                        detail: "Block one focus slot for the rest of the week",
                        icon: "shield.fill",
                        deepLink: "alltime://calendar?action=block",
                        impact: 5
                    )
                ],
                weekProjection: "At current pace, you'll finish the week with energy to spare."
            ),
            isLoading: false,
            onTap: {},
            onInterventionTap: { _ in }
        )

        // Drifting
        HeroSummaryCard(
            overview: nil,
            briefing: nil,
            driftStatus: WeekDriftStatus(
                driftScore: 55,
                severity: "drifting",
                severityLabel: "Drifting",
                dayOfWeek: 4,
                dayLabel: "THURSDAY",
                headline: "This week is drifting.",
                subheadline: "12h of meetings still ahead. One cut could change everything.",
                signals: DriftSignals(
                    meetingHoursThisWeek: 18,
                    meetingHoursRemaining: 12,
                    meetingCount: 22,
                    backToBackCount: 6,
                    eveningEncroachment: 2,
                    baselineMeetingHoursPerWeek: 12,
                    varianceFromBaseline: 50,
                    taskDeferrals: 4,
                    overdueCount: 2,
                    sleepDebtHours: 2,
                    activityGapPercent: 30
                ),
                interventions: [
                    DriftIntervention(
                        id: "reduce_meetings",
                        action: "Decline or shorten one meeting",
                        detail: "~2h back. Look for optional attendee meetings.",
                        icon: "calendar.badge.minus",
                        deepLink: "alltime://calendar?filter=meetings",
                        impact: 18
                    )
                ],
                weekProjection: "If nothing changes, this week ends in recovery mode."
            ),
            isLoading: false,
            onTap: {},
            onInterventionTap: { _ in }
        )
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
