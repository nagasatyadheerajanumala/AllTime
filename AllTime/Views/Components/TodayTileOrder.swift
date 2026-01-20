import SwiftUI
import Combine
import UniformTypeIdentifiers

// MARK: - Custom UTType for Tile Drag
extension UTType {
    static var todayTile: UTType {
        UTType(exportedAs: "com.alltime.todaytile")
    }
}

// MARK: - Today Reorderable Tile
/// Represents each tile that can appear on the Today screen.
/// Some tiles are reorderable, others are fixed in position.
enum TodayReorderableTile: String, CaseIterable, Identifiable, Codable, Transferable {

    // Transferable conformance for drag-and-drop
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .todayTile)
    }
    // Fixed tiles (always at top, not reorderable)
    case heroSummary = "hero_summary"
    case criticalHealthAlert = "critical_health_alert"

    // Reorderable tiles
    case primaryRecommendation = "primary_recommendation"
    case claraPrompts = "clara_prompts"
    case energyBudget = "energy_budget"
    case decisionMoments = "decision_moments"
    case similarWeek = "similar_week"
    case meetingSpots = "meeting_spots"
    case actionsRow = "actions_row"
    case upNext = "up_next"

    // Fixed tiles (always at bottom, not reorderable)
    case schedule = "schedule"
    case healthAccess = "health_access"

    var id: String { rawValue }

    /// Whether this tile can be reordered by the user
    var isReorderable: Bool {
        switch self {
        case .heroSummary, .criticalHealthAlert, .schedule, .healthAccess:
            return false
        default:
            return true
        }
    }

    /// Display name for accessibility and UI
    var displayName: String {
        switch self {
        case .heroSummary: return "Summary"
        case .criticalHealthAlert: return "Health Alert"
        case .primaryRecommendation: return "Do Now"
        case .claraPrompts: return "Clara"
        case .energyBudget: return "Energy"
        case .decisionMoments: return "Decisions"
        case .similarWeek: return "Similar Week"
        case .meetingSpots: return "Meeting Spots"
        case .actionsRow: return "Actions"
        case .upNext: return "Up Next"
        case .schedule: return "Schedule"
        case .healthAccess: return "Health Access"
        }
    }

    /// Icon for the tile (used in reorder UI)
    var icon: String {
        switch self {
        case .heroSummary: return "sun.max.fill"
        case .criticalHealthAlert: return "exclamationmark.heart.fill"
        case .primaryRecommendation: return "target"
        case .claraPrompts: return "sparkles"
        case .energyBudget: return "bolt.fill"
        case .decisionMoments: return "hand.tap.fill"
        case .similarWeek: return "calendar.badge.clock"
        case .meetingSpots: return "mappin.circle.fill"
        case .actionsRow: return "checklist"
        case .upNext: return "list.bullet.rectangle"
        case .schedule: return "calendar"
        case .healthAccess: return "heart.fill"
        }
    }

    /// Clara's default order for reorderable tiles
    static var claraDefaultOrder: [TodayReorderableTile] {
        [
            .primaryRecommendation,
            .claraPrompts,
            .energyBudget,
            .decisionMoments,
            .similarWeek,
            .meetingSpots,
            .actionsRow,
            .upNext
        ]
    }
}

// MARK: - Today Tile Order Manager
/// Manages the user's preferred tile ordering with persistence.
/// Provides drag-and-drop reordering with smooth animations.
@MainActor
final class TodayTileOrderManager: ObservableObject {

    // MARK: - Published Properties

    /// The current ordered list of reorderable tiles
    @Published private(set) var tileOrder: [TodayReorderableTile] = TodayReorderableTile.claraDefaultOrder

    /// Whether the user is currently in reorder mode
    @Published var isReorderModeActive: Bool = false

    /// The tile currently being dragged (for visual feedback)
    @Published var draggingTile: TodayReorderableTile? = nil

    // MARK: - Private Properties

    private let persistenceKey = "today_tile_order_v1"
    private let defaults = UserDefaults.standard

    // MARK: - Singleton

    static let shared = TodayTileOrderManager()

    // MARK: - Initialization

    private init() {
        loadSavedOrder()
    }

    // MARK: - Public Methods

    /// Move a tile from one position to another
    func moveTile(from source: IndexSet, to destination: Int) {
        var updatedOrder = tileOrder
        updatedOrder.move(fromOffsets: source, toOffset: destination)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tileOrder = updatedOrder
        }

        // Haptic feedback
        HapticManager.shared.lightTap()

        // Persist the new order
        saveOrder()
    }

    /// Move a tile to a new index (for drag and drop)
    func moveTile(_ tile: TodayReorderableTile, toIndex newIndex: Int) {
        guard let currentIndex = tileOrder.firstIndex(of: tile),
              currentIndex != newIndex,
              newIndex >= 0,
              newIndex < tileOrder.count else { return }

        var updatedOrder = tileOrder
        updatedOrder.remove(at: currentIndex)
        updatedOrder.insert(tile, at: min(newIndex, updatedOrder.count))

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            tileOrder = updatedOrder
        }

        HapticManager.shared.lightTap()
        saveOrder()
    }

    /// Enter reorder mode
    func enterReorderMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isReorderModeActive = true
        }
        HapticManager.shared.mediumTap()
    }

    /// Exit reorder mode
    func exitReorderMode() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isReorderModeActive = false
            draggingTile = nil
        }
        HapticManager.shared.lightTap()
    }

    /// Reset to Clara's default order
    func resetToDefault() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            tileOrder = TodayReorderableTile.claraDefaultOrder
        }

        HapticManager.shared.success()
        saveOrder()

        // Exit reorder mode after reset
        exitReorderMode()
    }

    /// Check if a tile should be visible (for conditional tiles)
    func index(of tile: TodayReorderableTile) -> Int? {
        tileOrder.firstIndex(of: tile)
    }

    // MARK: - Persistence

    private func saveOrder() {
        let rawValues = tileOrder.map { $0.rawValue }
        defaults.set(rawValues, forKey: persistenceKey)
    }

    private func loadSavedOrder() {
        guard let savedRawValues = defaults.stringArray(forKey: persistenceKey) else {
            // No saved order, use Clara's default
            tileOrder = TodayReorderableTile.claraDefaultOrder
            return
        }

        // Convert raw values back to tile types
        var loadedTiles: [TodayReorderableTile] = []
        for rawValue in savedRawValues {
            if let tile = TodayReorderableTile(rawValue: rawValue), tile.isReorderable {
                loadedTiles.append(tile)
            }
        }

        // Handle new tiles that might have been added since last save
        let defaultTiles = Set(TodayReorderableTile.claraDefaultOrder)
        let loadedTilesSet = Set(loadedTiles)
        let missingTiles = defaultTiles.subtracting(loadedTilesSet)

        // Append any new tiles to the end
        for tile in TodayReorderableTile.claraDefaultOrder {
            if missingTiles.contains(tile) {
                loadedTiles.append(tile)
            }
        }

        // Remove any tiles that no longer exist
        loadedTiles = loadedTiles.filter { defaultTiles.contains($0) }

        tileOrder = loadedTiles.isEmpty ? TodayReorderableTile.claraDefaultOrder : loadedTiles
    }
}

// MARK: - Reorderable Tile Wrapper
/// A wrapper view that adds reorder mode visual feedback and drag-and-drop to tiles
struct ReorderableTileWrapper<Content: View>: View {
    let tileType: TodayReorderableTile
    let content: () -> Content

    @ObservedObject private var orderManager = TodayTileOrderManager.shared
    @State private var isDragging = false

    var body: some View {
        content()
            .scaleEffect(scaleEffect)
            .opacity(dragOpacity)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
            .overlay(reorderOverlay)
            .onLongPressGesture(minimumDuration: 0.5) {
                if tileType.isReorderable {
                    orderManager.enterReorderMode()
                }
            }
            // Enable drag only when in reorder mode and tile is reorderable
            .if(orderManager.isReorderModeActive && tileType.isReorderable) { view in
                view
                    .draggable(tileType) {
                        // Drag preview - a compact representation
                        TileDragPreview(tile: tileType)
                            .onAppear {
                                isDragging = true
                                orderManager.draggingTile = tileType
                            }
                    }
                    .dropDestination(for: TodayReorderableTile.self) { droppedTiles, _ in
                        guard let droppedTile = droppedTiles.first,
                              droppedTile != tileType,
                              let targetIndex = orderManager.index(of: tileType) else {
                            return false
                        }
                        orderManager.moveTile(droppedTile, toIndex: targetIndex)
                        return true
                    } isTargeted: { isTargeted in
                        // Visual feedback when a drop target
                        withAnimation(.spring(response: 0.2)) {
                            // Could add highlight effect here
                        }
                    }
            }
            .onChange(of: orderManager.draggingTile) { _, newValue in
                if newValue == nil {
                    isDragging = false
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: orderManager.isReorderModeActive)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }

    private var scaleEffect: CGFloat {
        if isDragging {
            return 1.03
        } else if orderManager.isReorderModeActive && tileType.isReorderable {
            return 1.01
        }
        return 1.0
    }

    private var dragOpacity: Double {
        if isDragging && orderManager.draggingTile == tileType {
            return 0.5
        }
        return 1.0
    }

    private var shadowColor: Color {
        if isDragging {
            return Color.black.opacity(0.25)
        } else if orderManager.isReorderModeActive && tileType.isReorderable {
            return Color.black.opacity(0.1)
        }
        return Color.clear
    }

    private var shadowRadius: CGFloat {
        if isDragging {
            return 20
        } else if orderManager.isReorderModeActive && tileType.isReorderable {
            return 8
        }
        return 0
    }

    private var shadowY: CGFloat {
        if isDragging {
            return 10
        } else if orderManager.isReorderModeActive && tileType.isReorderable {
            return 4
        }
        return 0
    }

    @ViewBuilder
    private var reorderOverlay: some View {
        if orderManager.isReorderModeActive && tileType.isReorderable {
            VStack {
                HStack {
                    Spacer()

                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.tertiaryText)
                        .padding(8)
                        .background(
                            Circle()
                                .fill(DesignSystem.Colors.cardBackground)
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                }
                Spacer()
            }
        }
    }
}

// MARK: - Tile Drag Preview
/// A compact preview shown while dragging a tile
struct TileDragPreview: View {
    let tile: TodayReorderableTile

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tile.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primary)

            Text(tile.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundColor(DesignSystem.Colors.primaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
    }
}

// MARK: - Conditional View Modifier
extension View {
    /// Conditionally applies a transformation to the view
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Reorder Mode Header
/// A header that appears when reorder mode is active
struct ReorderModeHeader: View {
    @ObservedObject private var orderManager = TodayTileOrderManager.shared

    var body: some View {
        if orderManager.isReorderModeActive {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Customize Layout")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    Text("Drag tiles to reorder")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                Button(action: { orderManager.resetToDefault() }) {
                    Text("Reset")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                .padding(.trailing, 8)

                Button(action: { orderManager.exitReorderMode() }) {
                    Text("Done")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primary)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.cardBackground)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .padding(.horizontal, DesignSystem.Spacing.md)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }
}

// MARK: - View Extension
extension View {
    /// Wraps the view in a reorderable tile wrapper
    func reorderableTile(_ tileType: TodayReorderableTile) -> some View {
        ReorderableTileWrapper(tileType: tileType) {
            self
        }
    }
}
