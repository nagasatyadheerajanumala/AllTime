import SwiftUI

// MARK: - Collapsible Tile
/// A wrapper component that provides progressive disclosure for any tile.
/// Shows collapsed (glanceable) state by default, expands to full content on tap.
///
/// Design Principles:
/// - Default state: icon + title + 1 key signal (max 2 lines)
/// - Expanded state: full explanation, reasoning, CTA
/// - Smooth spring animation with haptic feedback
/// - Opacity hierarchy instead of borders
struct CollapsibleTile<CollapsedContent: View, ExpandedContent: View>: View {
    let tileId: String
    @ObservedObject var expansionManager: TileExpansionManager
    let collapsedContent: () -> CollapsedContent
    let expandedContent: () -> ExpandedContent

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header (always visible, tappable)
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack {
                    collapsedContent()
                    Spacer(minLength: 8)
                    expandIndicator
                }
            }
            .buttonStyle(TileButtonStyle())

            // Expanded content (conditionally shown)
            if isExpanded {
                expandedContent()
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }

    private var expandIndicator: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(DesignSystem.Colors.tertiaryText)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
    }
}

// MARK: - Minimal Collapsible Tile
/// An even more minimal version with just icon + label collapsed
struct MinimalCollapsibleTile<ExpandedContent: View>: View {
    let tileId: String
    let icon: String
    let iconColor: Color
    let title: String
    let signal: String?  // The ONE key signal shown when collapsed
    @ObservedObject var expansionManager: TileExpansionManager
    let expandedContent: () -> ExpandedContent

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed header
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 28, height: 28)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title + Signal
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(DesignSystem.Colors.primaryText)

                        if let signal = signal, !signal.isEmpty {
                            Text(signal)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                                .lineLimit(1)
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

            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.vertical, DesignSystem.Spacing.sm)

                expandedContent()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}

// MARK: - Compact Collapsible Tile
/// Ultra-compact tile for secondary information
/// Shows only icon + count/badge when collapsed
struct CompactCollapsibleTile<ExpandedContent: View>: View {
    let tileId: String
    let icon: String
    let iconColor: Color
    let title: String
    let badge: String?
    @ObservedObject var expansionManager: TileExpansionManager
    let expandedContent: () -> ExpandedContent

    private var isExpanded: Bool {
        expansionManager.isExpanded(tileId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Ultra-compact header
            Button(action: { expansionManager.toggle(tileId) }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(iconColor)

                    // Title
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Spacer()

                    // Badge (if any)
                    if let badge = badge, !badge.isEmpty {
                        Text(badge)
                            .font(.caption.weight(.medium))
                            .foregroundColor(iconColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(iconColor.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
            }
            .buttonStyle(TileButtonStyle())

            // Expanded content
            if isExpanded {
                expandedContent()
                    .padding(.top, DesignSystem.Spacing.sm)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg))
    }
}

// MARK: - Collapsible Section Header
/// Reusable header for collapsible sections within expanded tiles
struct CollapsibleSectionHeader: View {
    let title: String
    let icon: String?
    let iconColor: Color

    init(title: String, icon: String? = nil, iconColor: Color = DesignSystem.Colors.primary) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(iconColor)
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(DesignSystem.Colors.secondaryText)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Preview

#Preview {
    let manager = TileExpansionManager()

    ScrollView {
        VStack(spacing: 16) {
            MinimalCollapsibleTile(
                tileId: "energy",
                icon: "bolt.fill",
                iconColor: DesignSystem.Colors.emerald,
                title: "Energy",
                signal: "72% capacity",
                expansionManager: manager
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Energy breakdown and recommendations go here")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)

                    Button(action: {}) {
                        Text("Take Action")
                            .font(.subheadline.weight(.medium))
                    }
                }
            }

            CompactCollapsibleTile(
                tileId: "actions",
                icon: "sparkles",
                iconColor: DesignSystem.Colors.amber,
                title: "Actions",
                badge: "3",
                expansionManager: manager
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Action item 1")
                    Text("Action item 2")
                    Text("Action item 3")
                }
                .font(.subheadline)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            }

            CompactCollapsibleTile(
                tileId: "tasks",
                icon: "checklist",
                iconColor: DesignSystem.Colors.emerald,
                title: "Tasks",
                badge: "5 pending",
                expansionManager: manager
            ) {
                Text("Task list goes here")
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding()
    }
    .background(DesignSystem.Colors.background)
}
