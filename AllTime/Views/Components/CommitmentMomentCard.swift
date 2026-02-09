import SwiftUI

/// Top-of-screen commitment card — the daily commitment moment.
/// Shows when the user hasn't responded to today's commitment yet.
struct CommitmentMomentCard: View {
    let commitment: DailyCommitmentResponse
    let toneState: String?
    let onCommit: () -> Void
    let onChange: () -> Void
    let onDismiss: () -> Void

    @State private var animating = false

    private var accentColor: Color {
        switch toneState {
        case "ambitious": return DesignSystem.Colors.emerald
        case "protective": return DesignSystem.Colors.amber
        case "recovery": return Color(hex: "9CA3AF")
        case "permissive_reflective": return DesignSystem.Colors.blue
        default: return DesignSystem.Colors.primary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(accentColor)

                Text("Today's Commitment")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(DesignSystem.Colors.secondaryText)

                Spacer()
            }

            // The action
            Text(commitment.action ?? "Make today count")
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            // The reason
            if let reason = commitment.reason {
                Text(reason)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Commitment buttons
            HStack(spacing: 12) {
                // Commit button (primary)
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        animating = true
                    }
                    onCommit()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Commit")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(accentColor)
                    )
                }
                .scaleEffect(animating ? 1.05 : 1.0)

                // Change button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onChange()
                }) {
                    Text("Change")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .strokeBorder(DesignSystem.Colors.tertiaryText.opacity(0.3), lineWidth: 1)
                        )
                }

                // Dismiss button
                Button(action: {
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    onDismiss()
                }) {
                    Text("Skip")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }

                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .strokeBorder(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
