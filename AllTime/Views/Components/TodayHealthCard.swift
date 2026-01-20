import SwiftUI

/// Card displayed when Health data access is required
struct TodayHealthCard: View {
    @ObservedObject private var healthMetricsService = HealthMetricsService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(.white)

                Text("Health Data Access Required")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Clara needs access to your Health data to provide personalized insights.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    HealthAppHelper.openHealthAppSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.white)
                    )
                }

                Button(action: {
                    Task {
                        await healthMetricsService.checkAuthorizationStatus()
                        if healthMetricsService.isAuthorized {
                            await HealthSyncService.shared.syncRecentDays()
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Check")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                    )
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.red.opacity(0.8),
                            Color.orange.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.red.opacity(0.3), radius: 12, y: 4)
        )
    }
}

// MARK: - Compact Event Row
/// Compact row component for displaying events in lists
struct CompactEventRow: View {
    let event: Event
    let isCurrentEvent: Bool
    let isPastEvent: Bool

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Time
            if let startDate = event.startDate {
                Text(timeFormatter.string(from: startDate))
                    .font(.system(size: DesignSystem.FontSize.sm - 1, weight: .medium, design: .rounded))
                    .foregroundColor(timeColor)
                    .frame(width: 55, alignment: .leading)
            }

            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(event.sourceColorAsColor.opacity(isPastEvent ? 0.4 : 1.0))
                .frame(width: 3, height: DesignSystem.Components.avatarMedium)

            // Event details
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundColor(isPastEvent ? DesignSystem.Colors.tertiaryText : DesignSystem.Colors.primaryText)
                    .lineLimit(1)
                    .strikethrough(isPastEvent)

                if isCurrentEvent {
                    Text("Now")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.green)
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.xs + 2)
        .background(
            isCurrentEvent ?
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(Color.green.opacity(0.06))
            : nil
        )
    }

    private var timeColor: Color {
        if isCurrentEvent { return .green }
        if isPastEvent { return DesignSystem.Colors.tertiaryText }
        return DesignSystem.Colors.primaryText
    }
}
