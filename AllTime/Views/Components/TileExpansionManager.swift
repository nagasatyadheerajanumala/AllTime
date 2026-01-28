import SwiftUI
import Combine

// MARK: - Tile Expansion Manager
/// Manages accordion-style tile expansion where only one tile can be expanded at a time.
/// This reduces cognitive load by showing collapsed, scannable tiles by default.
final class TileExpansionManager: ObservableObject {

    /// The currently expanded tile ID. Nil means all tiles are collapsed.
    @Published private(set) var expandedTileId: String? = nil

    /// Tracks if any tile is animating (prevents rapid toggles)
    @Published private(set) var isAnimating: Bool = false

    // MARK: - Tile IDs (static identifiers for each tile type)

    enum TileId: String, CaseIterable {
        case hero = "hero"
        case primaryRecommendation = "primary_recommendation"
        case claraPrompts = "clara_prompts"
        case energyBudget = "energy_budget"
        case decisionMoments = "decision_moments"
        case similarWeek = "similar_week"
        case meetingSpots = "meeting_spots"
        case actions = "actions"
        case tasks = "tasks"
        case upNext = "up_next"
        case schedule = "schedule"
        case health = "health"
    }

    // MARK: - Public Methods

    /// Check if a specific tile is expanded
    func isExpanded(_ tileId: String) -> Bool {
        expandedTileId == tileId
    }

    /// Check if a specific tile is expanded (enum version)
    func isExpanded(_ tile: TileId) -> Bool {
        expandedTileId == tile.rawValue
    }

    /// Toggle a tile's expansion state
    /// If expanding, collapses any other expanded tile first
    func toggle(_ tileId: String) {
        print("🔲 TileExpansion: toggle(\(tileId)) called, isAnimating=\(isAnimating)")
        guard !isAnimating else {
            print("⚠️ TileExpansion: BLOCKED - isAnimating is true!")
            return
        }

        isAnimating = true
        print("🔲 TileExpansion: Setting isAnimating=true, expandedTileId before: \(expandedTileId ?? "nil")")

        // Provide haptic feedback
        HapticManager.shared.lightTap()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            if expandedTileId == tileId {
                // Collapse if already expanded
                expandedTileId = nil
                print("🔲 TileExpansion: Collapsing \(tileId)")
            } else {
                // Expand this tile (automatically collapses others)
                expandedTileId = tileId
                print("🔲 TileExpansion: Expanding \(tileId)")
            }
        }

        // Reset animation lock after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isAnimating = false
            print("🔲 TileExpansion: Reset isAnimating=false")
        }
    }

    /// Toggle a tile's expansion state (enum version)
    func toggle(_ tile: TileId) {
        toggle(tile.rawValue)
    }

    /// Collapse all tiles
    func collapseAll() {
        guard expandedTileId != nil else { return }

        HapticManager.shared.lightTap()

        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            expandedTileId = nil
        }
    }

    /// Force expand a specific tile (used for programmatic expansion)
    func expand(_ tileId: String) {
        guard expandedTileId != tileId else { return }

        HapticManager.shared.lightTap()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            expandedTileId = tileId
        }
    }
}

// MARK: - Environment Key

private struct TileExpansionManagerKey: EnvironmentKey {
    static let defaultValue = TileExpansionManager()
}

extension EnvironmentValues {
    var tileExpansionManager: TileExpansionManager {
        get { self[TileExpansionManagerKey.self] }
        set { self[TileExpansionManagerKey.self] = newValue }
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Inject the tile expansion manager into the environment
    func withTileExpansion(_ manager: TileExpansionManager) -> some View {
        environment(\.tileExpansionManager, manager)
    }
}
