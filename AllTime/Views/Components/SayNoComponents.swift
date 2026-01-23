import SwiftUI

// MARK: - Say No Section View
/// The "Say No" system - identifies meetings to decline and provides one-tap actions.
/// This is the UNIQUE feature that Google/Apple cannot easily copy.
/// It requires longitudinal data about user patterns, meeting outcomes, and energy states.
struct SayNoSectionView: View {
    let recommendations: [DeclineRecommendationDTO]
    let onRecommendationTap: (DeclineRecommendationDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.errorRed)

                Text("Say No")
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                // Badge showing count
                Text("\(recommendations.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.errorRed)
                    )
            }

            // Subtitle - directive, not suggestive
            Text("These meetings cost more than they deliver.")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.secondaryText)

            // Recommendation cards
            ForEach(recommendations) { recommendation in
                DeclineRecommendationCard(
                    recommendation: recommendation,
                    onTap: { onRecommendationTap(recommendation) }
                )
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.errorRed.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Decline Recommendation Card
struct DeclineRecommendationCard: View {
    let recommendation: DeclineRecommendationDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Left: Reason icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.errorRed.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: recommendation.reasonIcon)
                        .font(.system(size: 18))
                        .foregroundColor(DesignSystem.Colors.errorRed)
                }

                // Middle: Meeting info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.meetingTitle ?? "Meeting")
                        .font(DesignSystem.Typography.body.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(1)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Time
                        if let timeLabel = recommendation.formattedMeetingTime {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(timeLabel)
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                        }

                        // Duration
                        HStack(spacing: 2) {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                            Text(recommendation.formattedDuration)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }

                    // Reason - directive language
                    Text(recommendation.declineReasonHuman ?? "Low value meeting")
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.errorRed)
                        .lineLimit(1)
                }

                Spacer()

                // Right: Suggested action button
                VStack(spacing: 4) {
                    Image(systemName: recommendation.suggestedActionIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.errorRed)
                        )

                    Text(recommendation.suggestedActionLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.errorRed)
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(DesignSystem.Colors.secondaryBackground)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Protected Time Block Card
/// Shows the user's protected time block for focus/recovery.
/// This is intelligence-driven, not just a calendar display.
struct ProtectedTimeBlockCard: View {
    let protectedTime: ProtectedTimeBlock

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header
            HStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.violet)

                Text("Protected Time")
                    .font(DesignSystem.Typography.sectionHeader)
                    .foregroundColor(DesignSystem.Colors.primaryText)

                Spacer()

                // Duration badge
                Text(protectedTime.formattedDuration)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(DesignSystem.Colors.violet)
                    )
            }

            // Time block info
            HStack(spacing: DesignSystem.Spacing.md) {
                // Time range
                VStack(alignment: .leading, spacing: 4) {
                    if let startTime = protectedTime.startTime,
                       let endTime = protectedTime.endTime {
                        Text("\(startTime) - \(endTime)")
                            .font(DesignSystem.Typography.body.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }

                    if let reason = protectedTime.reason {
                        Text(reason)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }

                Spacer()

                // Action button (if available)
                if let actionText = protectedTime.actionText {
                    Button(action: {
                        // Handle deep link
                        if let deepLink = protectedTime.actionDeepLink {
                            NavigationManager.shared.handleDestination(deepLink)
                        }
                    }) {
                        Text(actionText)
                            .font(DesignSystem.Typography.caption.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.violet)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(DesignSystem.Colors.violet.opacity(0.15))
                            )
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.violet.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Decline Action Sheet
/// Minimal decline workflow - just actions, no explanations.
struct DeclineActionSheet: View {
    let recommendation: DeclineRecommendationDTO
    let onDecline: () -> Void
    let onReschedule: () -> Void
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showMessage = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.Colors.tertiaryText.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            // Meeting name + time only
            VStack(spacing: 8) {
                Text(recommendation.meetingTitle ?? "Meeting")
                    .font(.headline)
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                Text(recommendation.formattedMeetingTime ?? "")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Big action buttons - no text labels, just icons
            HStack(spacing: 16) {
                // Decline
                Button(action: {
                    onDecline()
                    dismiss()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(DesignSystem.Colors.errorRed))

                        Text("Decline")
                            .font(.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.errorRed)
                    }
                }

                // Reschedule
                Button(action: {
                    onReschedule()
                    dismiss()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(DesignSystem.Colors.amber))

                        Text("Later")
                            .font(.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.amber)
                    }
                }

                // Keep
                Button(action: {
                    onDismiss()
                    dismiss()
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 64, height: 64)
                            .background(Circle().fill(DesignSystem.Colors.emerald))

                        Text("Keep")
                            .font(.caption.weight(.medium))
                            .foregroundColor(DesignSystem.Colors.emerald)
                    }
                }
            }
            .padding(.bottom, 24)

            // Copy message button (small, secondary)
            Button(action: {
                let message = recommendation.declineMessage ?? "I need to decline this meeting. I have conflicting priorities."
                UIPasteboard.general.string = message
                showMessage = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showMessage = false }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: showMessage ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                    Text(showMessage ? "Copied!" : "Copy message")
                        .font(.caption)
                }
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            }
            .padding(.bottom, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.cardBackground)
        .presentationDetents([.height(280)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - Time Intelligence Status Card
/// Shows the overall Time Intelligence status at a glance.
struct TimeIntelligenceStatusCard: View {
    let intelligence: TimeIntelligenceResponse

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with capacity status
            HStack {
                // Capacity indicator
                ZStack {
                    Circle()
                        .fill(intelligence.capacityColor.opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: intelligence.capacityIcon)
                        .font(.system(size: 24))
                        .foregroundColor(intelligence.capacityColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(intelligence.capacityStatus?.capitalized ?? "Status Unknown")
                        .font(DesignSystem.Typography.sectionHeader)
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("\(intelligence.capacityOverloadPercent)% capacity used")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(intelligence.capacityColor)
                }

                Spacer()

                // Day quality badge
                if let quality = intelligence.predictedDayQuality {
                    VStack(spacing: 2) {
                        Text("\(quality)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(intelligence.dayQualityColor)

                        Text("Quality")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.tertiaryText)
                    }
                }
            }

            // The Directive - THE ONE thing to do
            if let directive = intelligence.primaryDirective {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: intelligence.directiveIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(intelligence.directiveColor)

                    Text(directive)
                        .font(DesignSystem.Typography.body.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                }
                .padding(DesignSystem.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(intelligence.directiveColor.opacity(0.1))
                )
            }

            // Quick metrics row
            if let metrics = intelligence.metrics {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    MetricPill(
                        icon: "brain.head.profile",
                        label: "Focus Load",
                        value: "\(metrics.focusLoad ?? 0)%"
                    )

                    MetricPill(
                        icon: "calendar",
                        label: "Meetings",
                        value: metrics.formattedMeetingTime
                    )

                    MetricPill(
                        icon: "target",
                        label: "Focus",
                        value: metrics.formattedFocusTime
                    )
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

// MARK: - Metric Pill
struct MetricPill: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(DesignSystem.Colors.secondaryText)

            Text(value)
                .font(DesignSystem.Typography.caption.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.primaryText)

            Text(label)
                .font(.system(size: 9))
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Previews
#Preview("Say No Section") {
    ZStack {
        DesignSystem.Colors.background.ignoresSafeArea()

        SayNoSectionView(
            recommendations: [
                DeclineRecommendationDTO(
                    id: 1,
                    eventId: 100,
                    meetingTitle: "Weekly Status Update",
                    meetingStartTime: "2024-01-15T14:00:00Z",
                    meetingDurationMinutes: 60,
                    declineReasonCode: "back_to_back_overload",
                    declineReasonHuman: "Creates 4-hour back-to-back chain",
                    costOfAttending: 75,
                    valueOfAttending: 20,
                    netScore: -55,
                    suggestedAction: "decline",
                    declineMessage: "I need to decline this meeting.",
                    rescheduleMessage: nil,
                    confidence: 85
                )
            ],
            onRecommendationTap: { _ in }
        )
        .padding()
    }
    .preferredColorScheme(.dark)
}
