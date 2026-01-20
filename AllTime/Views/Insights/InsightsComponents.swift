import SwiftUI

// MARK: - Insights Shared Components
// Premium, calm, consistent components for the Insights tab

// MARK: - Section Header

struct InsightSectionHeader: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = DesignSystem.Colors.primary
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            Spacer()
        }
    }
}

// MARK: - Clara Card (AI Narrative Hero)

struct ClaraCard: View {
    let narrative: String
    let isExpanded: Bool
    let onToggle: () -> Void

    private var displayText: String {
        if isExpanded {
            return narrative
        } else {
            // Show first 2 sentences or ~120 characters
            let sentences = narrative.components(separatedBy: ". ")
            if sentences.count > 2 {
                return sentences.prefix(2).joined(separator: ". ") + "..."
            } else if narrative.count > 150 {
                return String(narrative.prefix(150)) + "..."
            }
            return narrative
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.primary)

                Text("Clara's Insight")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()
            }

            // Narrative Text
            Text(displayText)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            // Expand/Collapse Button
            if narrative.count > 150 || narrative.components(separatedBy: ". ").count > 2 {
                Button(action: onToggle) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "Show less" : "Read more")
                            .font(.caption.weight(.medium))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundColor(DesignSystem.Colors.primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.primary.opacity(0.15), lineWidth: 1)
                )
        )
        .animation(.easeInOut(duration: 0.25), value: isExpanded)
    }
}

// MARK: - Metric Chip

struct MetricChip: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let trend: MetricTrend?

    enum MetricTrend {
        case up, down, stable

        var icon: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .stable: return "minus"
            }
        }

        var color: Color {
            switch self {
            case .up: return DesignSystem.Colors.emerald
            case .down: return DesignSystem.Colors.errorRed
            case .stable: return Color(hex: "6B7280")
            }
        }
    }

    init(
        icon: String,
        value: String,
        label: String,
        color: Color = DesignSystem.Colors.primary,
        trend: MetricTrend? = nil
    ) {
        self.icon = icon
        self.value = value
        self.label = label
        self.color = color
        self.trend = trend
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    if let trend = trend {
                        Image(systemName: trend.icon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(trend.color)
                    }
                }

                Text(label)
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(color.opacity(0.08))
        )
    }
}

// MARK: - Ranked Issue Row

struct RankedIssueRow: View {
    let rank: Int
    let title: String
    let detail: String
    let severity: IssueSeverity
    let isExpanded: Bool
    let onTap: () -> Void

    enum IssueSeverity {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return DesignSystem.Colors.errorRed
            case .medium: return DesignSystem.Colors.amber
            case .low: return DesignSystem.Colors.blue
            }
        }

        var icon: String {
            switch self {
            case .high: return "exclamationmark.circle.fill"
            case .medium: return "exclamationmark.triangle.fill"
            case .low: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Main Row
                HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                    // Rank Badge
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(severity.color)
                        )

                    // Title
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(isExpanded ? nil : 1)

                    Spacer()

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, DesignSystem.Spacing.sm)

                // Expanded Detail
                if isExpanded {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Rectangle()
                            .fill(severity.color.opacity(0.3))
                            .frame(width: 2)
                            .padding(.leading, 10)

                        Text(detail)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, DesignSystem.Spacing.sm)
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(severity.color.opacity(isExpanded ? 0.3 : 0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Action Recommendation Card

struct ActionRecommendationCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let actionLabel: String?
    let onAction: (() -> Void)?

    init(
        title: String,
        description: String,
        icon: String = "lightbulb.fill",
        color: Color = DesignSystem.Colors.emerald,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.icon = icon
        self.color = color
        self.actionLabel = actionLabel
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(color.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            // Action Button (optional)
            if let actionLabel = actionLabel, let onAction = onAction {
                Button(action: onAction) {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                            .font(.caption.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundColor(color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.1))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 36) // Align with text
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Skeleton Loading Components
// Note: Uses SkeletonView from BriefingExtensions.swift

struct InsightsSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Hero Card Skeleton
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    SkeletonView()
                        .frame(width: 24, height: 24)
                    SkeletonView()
                        .frame(width: 100, height: 16)
                    Spacer()
                }

                SkeletonView()
                    .frame(height: 14)
                SkeletonView()
                    .frame(height: 14)
                SkeletonView()
                    .frame(width: 200, height: 14)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Metrics Row Skeleton
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonView()
                            .frame(width: 100, height: 50)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
            }

            // Section Header Skeleton
            HStack {
                SkeletonView()
                    .frame(width: 20, height: 20)
                SkeletonView()
                    .frame(width: 140, height: 18)
                Spacer()
            }

            // Issue Rows Skeleton
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    SkeletonView()
                        .frame(width: 22, height: 22)
                        .cornerRadius(11)
                    SkeletonView()
                        .frame(height: 16)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }

            // Action Cards Skeleton
            HStack {
                SkeletonView()
                    .frame(width: 20, height: 20)
                SkeletonView()
                    .frame(width: 120, height: 18)
                Spacer()
            }

            ForEach(0..<2, id: \.self) { _ in
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        SkeletonView()
                            .frame(width: 28, height: 28)
                            .cornerRadius(14)
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonView()
                                .frame(width: 150, height: 14)
                            SkeletonView()
                                .frame(height: 12)
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
        .padding(.horizontal, DesignSystem.Spacing.screenMargin)
    }
}

// MARK: - Empty State View

struct InsightsEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionLabel: String?
    let onAction: (() -> Void)?

    init(
        icon: String = "chart.line.uptrend.xyaxis",
        title: String = "No Insights Yet",
        message: String = "Connect your calendar and health data to see personalized insights.",
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
        self.onAction = onAction
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.tertiaryText)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            if let actionLabel = actionLabel, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionLabel)
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
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Error State View

struct InsightsErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(DesignSystem.Colors.warning)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Unable to Load Insights")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }

            Button(action: onRetry) {
                HStack(spacing: 6) {
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
}

// MARK: - Pattern Row (Softer alternative to RankedIssueRow)
// Used in "Patterns to Watch" section - neutral styling, no alert colors

struct PatternRow: View {
    let rank: Int
    let title: String
    let detail: String
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Main Row
                HStack(alignment: .center, spacing: DesignSystem.Spacing.sm) {
                    // Rank Badge - neutral gray instead of colored
                    Text("\(rank)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.cardBackgroundElevated)
                        )

                    // Title
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(isExpanded ? nil : 1)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // Chevron
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, DesignSystem.Spacing.sm)

                // Expanded Detail - softer styling
                if isExpanded {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Rectangle()
                            .fill(DesignSystem.Colors.calmBorder)
                            .frame(width: 2)
                            .padding(.leading, 10)

                        Text(detail)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, DesignSystem.Spacing.sm)
                    }
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            InsightSectionHeader(
                title: "Your Current State",
                subtitle: "Based on this week's data",
                icon: "brain.head.profile",
                iconColor: DesignSystem.Colors.primary
            )

            ClaraCard(
                narrative: "This week has been intense with back-to-back meetings. Your average sleep dropped to 6.2 hours, which is below your goal. Consider blocking some recovery time.",
                isExpanded: false,
                onToggle: {}
            )

            HStack(spacing: 8) {
                MetricChip(icon: "calendar", value: "23", label: "Meetings", color: DesignSystem.Colors.blue)
                MetricChip(icon: "moon.fill", value: "6.2h", label: "Avg Sleep", color: DesignSystem.Colors.violet, trend: .down)
            }

            RankedIssueRow(
                rank: 1,
                title: "Too Many Back-to-Back Meetings",
                detail: "You had 5 days with 3+ back-to-back meetings this week. This leaves no buffer time for breaks or preparation.",
                severity: .high,
                isExpanded: true,
                onTap: {}
            )

            // PatternRow - softer alternative
            PatternRow(
                rank: 1,
                title: "Meeting clusters observed",
                detail: "You had 5 days with 3+ back-to-back meetings this week. Consider adding buffers between meetings.",
                isExpanded: true,
                onTap: {}
            )

            ActionRecommendationCard(
                title: "Block Recovery Time",
                description: "Add 15-minute buffers between meetings to reduce cognitive load.",
                icon: "clock.badge.checkmark",
                color: DesignSystem.Colors.emerald,
                actionLabel: "Add Buffers",
                onAction: {}
            )

            InsightsSkeleton()
        }
        .padding()
    }
    .background(DesignSystem.Colors.background)
    .preferredColorScheme(.dark)
}
