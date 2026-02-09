import SwiftUI

/// Displays the ONE primary insight — Clara's verdict for the day.
/// Severity drives visual treatment: critical = red, warning = amber, positive = green, info = blue.
struct PrimaryInsightCard: View {
    let insight: PrimaryInsight

    private var severityColor: Color {
        switch insight.severity {
        case "critical": return Color(hex: "EF4444")
        case "warning": return DesignSystem.Colors.amber
        case "positive": return DesignSystem.Colors.emerald
        default: return DesignSystem.Colors.blue
        }
    }

    private var severityIcon: String {
        if let icon = insight.icon, !icon.isEmpty { return icon }
        switch insight.severity {
        case "critical": return "exclamationmark.triangle.fill"
        case "warning": return "exclamationmark.circle.fill"
        case "positive": return "checkmark.seal.fill"
        default: return "brain.head.profile"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: severityIcon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(severityColor)
                .frame(width: 32, height: 32)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                if let headline = insight.headline {
                    Text(headline)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let body = insight.body {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(severityColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .strokeBorder(severityColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
