import SwiftUI

/// Clara takes health seriously - this banner shows when health is critical or data is suspect
/// This is NOT optional information - it demands attention
struct CriticalHealthAlertBanner: View {
    let metrics: BriefingKeyMetrics

    private var isSuspect: Bool {
        metrics.isHealthDataSuspect
    }

    private var isCritical: Bool {
        metrics.isHealthCritical && !isSuspect
    }

    private var bannerGradient: LinearGradient {
        if isSuspect {
            return DesignSystem.Colors.warningGradient
        } else {
            return DesignSystem.Colors.errorGradient
        }
    }

    private var icon: String {
        isSuspect ? "questionmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var title: String {
        if isSuspect {
            return "Health Data Looks Wrong"
        } else {
            return "Health Alert"
        }
    }

    private var message: String {
        if let reason = metrics.healthEscalationMessage, !reason.isEmpty {
            return reason
        }

        if isSuspect {
            if let sleep = metrics.sleepHoursLastNight, sleep < 1 {
                return "\(String(format: "%.1f", sleep))h sleep recorded. This may be a sync issue. If accurate, you're operating severely impaired."
            }
            return "Some health values look incorrect. Check your data sync."
        }

        if let sleep = metrics.sleepHoursLastNight {
            if sleep < 4 {
                return "Only \(String(format: "%.1f", sleep))h sleep. Your cognitive function is significantly impaired. Avoid important decisions."
            } else if sleep < 5 {
                return "\(String(format: "%.1f", sleep))h sleep is in dangerous territory. Expect reduced focus and slower reaction times."
            }
        }

        return "Your health metrics need attention today."
    }

    private var actionText: String {
        if isSuspect {
            return "Check Health app sync"
        } else {
            return "Protect yourself today"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Header row
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Pulsing icon for critical
                ZStack {
                    if isCritical {
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: DesignSystem.Components.avatarMedium + 4, height: DesignSystem.Components.avatarMedium + 4)
                            .scaleEffect(1.2)
                            .animation(
                                Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: isCritical
                            )
                    }

                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.Components.iconLarge, weight: .bold))
                        .foregroundColor(.white)
                }

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundColor(.white)

                Spacer()

                // Severity badge
                Text(isSuspect ? "VERIFY" : "CRITICAL")
                    .font(.caption2.weight(.heavy))
                    .foregroundColor(isSuspect ? DesignSystem.Colors.warningYellow : DesignSystem.Colors.errorRed)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
            }

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            // Bottom row with action hint
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: DesignSystem.Components.iconMedium))
                    .foregroundColor(.white.opacity(0.8))

                Text(actionText)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                // Sleep hours if available
                if let sleep = metrics.sleepHoursLastNight {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.caption)
                        Text(String(format: "%.1fh", sleep))
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(bannerGradient)
                .shadow(color: (isSuspect ? DesignSystem.Colors.warningYellow : DesignSystem.Colors.errorRed).opacity(0.4), radius: 12, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}
