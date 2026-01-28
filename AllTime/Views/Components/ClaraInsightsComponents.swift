import SwiftUI

// MARK: - Primary Recommendation Card
/// The ONE non-negotiable recommendation for today.
/// Clara is opinionated - this is THE thing to do, not a suggestion list.
struct PrimaryRecommendationCard: View {
    let recommendation: PrimaryRecommendation
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with urgency badge
                HStack {
                    Image(systemName: recommendation.displayIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(recommendation.urgencyColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recommendation.urgencyLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(recommendation.urgencyColor)
                            .textCase(.uppercase)

                        if recommendation.isHighConfidence {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 10))
                                Text("Clara recommends")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }

                // Main action text
                Text(recommendation.action)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Reason
                if let reason = recommendation.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                // Consequence warning (if ignored)
                if let consequence = recommendation.ignoredConsequence, !consequence.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                        Text(consequence)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(DesignSystem.Colors.amber)
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(recommendation.urgencyColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Energy Budget Card
/// Shows how today's inputs (sleep, meetings, activity) transform into energy capacity.
struct EnergyBudgetCard: View {
    let energyBudget: EnergyBudget
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                HStack {
                    // Energy level indicator
                    ZStack {
                        Circle()
                            .stroke(DesignSystem.Colors.tertiaryText.opacity(0.3), lineWidth: 4)
                            .frame(width: 44, height: 44)

                        Circle()
                            .trim(from: 0, to: energyBudget.levelPercentage)
                            .stroke(energyBudget.capacityColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))

                        Text("\(energyBudget.currentLevel ?? 50)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(energyBudget.capacityLabel ?? "Energy")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        HStack(spacing: 4) {
                            Image(systemName: energyBudget.trajectoryIcon)
                                .font(.system(size: 12))
                            Text(energyBudget.trajectoryLabel ?? "")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(energyBudget.trajectoryColor)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()

                    // Energy factors
                    if let drains = energyBudget.energyDrains, !drains.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Energy Drains")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .textCase(.uppercase)

                            ForEach(drains, id: \.factorId) { factor in
                                EnergyFactorRow(factor: factor)
                            }
                        }
                    }

                    if let deposits = energyBudget.energyDeposits, !deposits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Energy Deposits")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .textCase(.uppercase)

                            ForEach(deposits, id: \.factorId) { factor in
                                EnergyFactorRow(factor: factor)
                            }
                        }
                    }

                    // Peak and low windows
                    HStack(spacing: 16) {
                        if let peak = energyBudget.peakWindow {
                            EnergyWindowBadge(
                                title: "Peak",
                                time: peak.displayLabel,
                                icon: "arrow.up",
                                color: DesignSystem.Colors.emerald
                            )
                        }
                        if let low = energyBudget.lowWindow {
                            EnergyWindowBadge(
                                title: "Low",
                                time: low.displayLabel,
                                icon: "arrow.down",
                                color: DesignSystem.Colors.amber
                            )
                        }
                    }

                    // Recovery recommendation
                    if energyBudget.needsRecovery, let recommendation = energyBudget.recoveryRecommendation {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(DesignSystem.Colors.errorRed)
                            Text(recommendation)
                                .font(.system(size: 13))
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        .padding(12)
                        .background(DesignSystem.Colors.errorRed.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Energy Factor Row
struct EnergyFactorRow: View {
    let factor: BriefingEnergyFactor

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: factor.displayIcon)
                .font(.system(size: 14))
                .foregroundColor(factor.impactColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(factor.label ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let detail = factor.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer()

            Text(factor.formattedImpact)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(factor.impactColor)
        }
    }
}

// MARK: - Energy Window Badge
struct EnergyWindowBadge: View {
    let title: String
    let time: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
            }
            .foregroundColor(color)

            Text(time)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Clara Assistant Card
/// Beautiful AI assistant card with contextual prompts
struct ClaraPromptsRow: View {
    let prompts: [ClaraPrompt]
    var onPromptTap: ((ClaraPrompt) -> Void)? = nil

    // Clara gradient colors
    private let claraGradient = LinearGradient(
        colors: [
            DesignSystem.Colors.violet,
            DesignSystem.Colors.claraPurpleLight,
            DesignSystem.Colors.violetDark
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            // Clara Header
            HStack(spacing: 12) {
                // Clara Avatar
                ZStack {
                    Circle()
                        .fill(claraGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: DesignSystem.Colors.violet.opacity(0.4), radius: 8, y: 4)

                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Clara")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("Your AI assistant")
                        .font(.system(size: 13))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                // Online indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignSystem.Colors.emerald)
                        .frame(width: 8, height: 8)
                    Text("Ready")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.emerald)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(DesignSystem.Colors.emerald.opacity(0.1))
                .clipShape(Capsule())
            }
            .padding(16)

            Divider()
                .background(DesignSystem.Colors.calmBorder)

            // Prompt Suggestions
            VStack(alignment: .leading, spacing: 12) {
                Text("What can I help with?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(prompts.prefix(4), id: \.promptId) { prompt in
                            ClaraPromptBubble(prompt: prompt) {
                                onPromptTap?(prompt)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }
        }
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [DesignSystem.Colors.violet.opacity(0.3), DesignSystem.Colors.claraPurpleLight.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: DesignSystem.Colors.violet.opacity(0.1), radius: 20, y: 10)
    }
}

// MARK: - Clara Prompt Bubble
/// Chat bubble style prompt suggestion
struct ClaraPromptBubble: View {
    let prompt: ClaraPrompt
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 8) {
                // Icon
                ZStack {
                    Circle()
                        .fill(prompt.categoryColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: prompt.displayIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(prompt.categoryColor)
                }

                // Label
                Text(prompt.label ?? "Ask me")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 120, alignment: .leading)
            .padding(12)
            .background(DesignSystem.Colors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(prompt.categoryColor.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - Legacy Clara Prompt Chip (kept for compatibility)
struct ClaraPromptChip: View {
    let prompt: ClaraPrompt
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 6) {
                Image(systemName: prompt.displayIcon)
                    .font(.system(size: 12, weight: .medium))

                Text(prompt.label ?? "")
                    .font(.system(size: 13, weight: .medium))

                if prompt.isContextSpecific {
                    Circle()
                        .fill(prompt.categoryColor)
                        .frame(width: 6, height: 6)
                }
            }
            .foregroundColor(DesignSystem.Colors.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(DesignSystem.Colors.secondaryBackground)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(prompt.categoryColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Compact Primary Recommendation (for inline display)
struct CompactPrimaryRecommendation: View {
    let recommendation: PrimaryRecommendation
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                Image(systemName: recommendation.displayIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(recommendation.urgencyColor)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.action)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    Text(recommendation.urgencyLabel)
                        .font(.system(size: 12))
                        .foregroundColor(recommendation.urgencyColor)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(12)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Opportunity Insight Card
/// Shows leverage windows and opportunities - the positive counterbalance to risks.
/// Part of the 1 Risk + 1 Opportunity + 1 Recommendation model.
struct OpportunityInsightCard: View {
    let opportunity: OpportunityInsight
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with type badge
                HStack {
                    Image(systemName: opportunity.displayIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(opportunity.typeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(opportunity.typeLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(opportunity.typeColor)
                            .textCase(.uppercase)

                        if opportunity.isHighConfidence {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text("Rare opportunity")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    Spacer()

                    if let window = opportunity.windowLabel {
                        Text(window)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.secondaryBackground)
                            .clipShape(Capsule())
                    }
                }

                // Headline
                Text(opportunity.displayHeadline)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Reason
                if let reason = opportunity.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                // Suggested use
                if let suggestedUse = opportunity.suggestedUse, !suggestedUse.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                        Text(suggestedUse)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(opportunity.typeColor)
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(opportunity.typeColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Risk Insight Card
/// Shows the single most important risk - uses existing CapacityInsight styling.
struct RiskInsightCard: View {
    let risk: CapacityInsight
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with severity icon
                HStack {
                    Image(systemName: risk.severityIcon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(risk.severityColor)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Risk")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(risk.severityColor)
                            .textCase(.uppercase)

                        Text(risk.severity.capitalized)
                            .font(.system(size: 11))
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    Spacer()
                }

                // Title
                Text(risk.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .multilineTextAlignment(.leading)

                // Description
                Text(risk.description)
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                // Actionable advice
                if let actionable = risk.actionable, !actionable.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12))
                        Text(actionable)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(risk.severityColor)
                    .padding(.top, 4)
                }
            }
            .padding(16)
            .background(DesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(risk.severityColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Risk + Opportunity Section
/// Combined section showing 1 Risk + 1 Opportunity side by side or stacked
struct RiskOpportunitySectionView: View {
    let riskInsight: CapacityInsight?
    let opportunityInsight: OpportunityInsight?
    var onRiskTap: (() -> Void)? = nil
    var onOpportunityTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Section header
            HStack {
                Text("Today's Intelligence")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .textCase(.uppercase)
                Spacer()
            }

            // Show opportunity first (positive framing), then risk
            if let opportunity = opportunityInsight {
                OpportunityInsightCard(opportunity: opportunity, onTap: onOpportunityTap)
            }

            if let risk = riskInsight {
                RiskInsightCard(risk: risk, onTap: onRiskTap)
            }

            // Empty state
            if riskInsight == nil && opportunityInsight == nil {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.emerald)
                    Text("No significant risks or special opportunities today")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(DesignSystem.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Preview Provider
#if DEBUG
struct ClaraInsightsComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Preview content would go here
                Text("Clara Insights Components")
                    .font(.headline)
            }
            .padding()
        }
        .background(DesignSystem.Colors.background)
    }
}
#endif
