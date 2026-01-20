import SwiftUI
import UIKit

// MARK: - Chrona Design System with Light/Dark Theme Support
struct DesignSystem {

    // MARK: - Colors - Adaptive Light/Dark Theme
    struct Colors {
        // Primary Accent - Chrona Blue (works in both themes)
        static let primary = Color(hex: "3B82F6") // Unified Chrona blue
        static let primaryDark = Color(hex: "2563EB")
        static let primaryLight = Color(hex: "60A5FA")

        // Accent Colors (work well in both themes)
        static let accent = Color(hex: "FF6B6B")
        static let success = Color(hex: "34C759") // iOS Green
        static let warning = Color(hex: "FF9500") // iOS Orange
        static let info = Color(hex: "5AC8FA") // iOS Cyan

        // MARK: Calm UI Colors (adaptive)
        static let calmSurface = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "0F0F0F") : UIColor(hex: "F5F5F7")
        })
        static let calmBorder = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.06) : UIColor.black.withAlphaComponent(0.08)
        })
        static let calmAccent = Color(hex: "6366F1").opacity(0.8) // Muted indigo

        // Softer Alert Colors (less alarming)
        static let softWarning = Color(hex: "F59E0B").opacity(0.7)
        static let softCritical = Color(hex: "EF4444").opacity(0.6)
        static let softSuccess = Color(hex: "10B981").opacity(0.8)
        static let neutralBlue = Color(hex: "3B82F6") // For "patterns" instead of "problems"

        // MARK: Hero & Calm Gradients (adaptive)
        static var heroGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "1E1B4B"), Color(hex: "0F0D24")], // Deep indigo (works in both)
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        static var insightsGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "2E1065").opacity(0.8), Color(hex: "1E1B4B").opacity(0.6)], // Muted purple
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        // Today Screen Tile Colors (keeping for backwards compatibility)
        static let todayTileGradient = LinearGradient(
            colors: [Color(hex: "6366F1"), Color(hex: "4F46E5")], // Indigo
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let suggestionsTileGradient = LinearGradient(
            colors: [Color(hex: "F59E0B"), Color(hex: "D97706")], // Amber/Orange
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        static let todoTileGradient = LinearGradient(
            colors: [Color(hex: "10B981"), Color(hex: "059669")], // Emerald/Green
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Event Category Colors
        static let eventColors: [Color] = [
            Color(hex: "FF6B6B"), // Red
            Color(hex: "4ECDC4"), // Teal
            Color(hex: "FFE66D"), // Yellow
            Color(hex: "A8E6CF"), // Mint
            Color(hex: "FF8B94"), // Pink
            Color(hex: "B4A7D6"), // Purple
            Color(hex: "FFD3B6"), // Peach
            Color(hex: "95E1D3"), // Aqua
        ]

        // MARK: - Adaptive Background Colors
        static let background = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "000000") : UIColor(hex: "F2F2F7")
        })
        static let backgroundLifted = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "050505") : UIColor(hex: "FFFFFF")
        })
        static let backgroundLifted2 = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "0A0A0A") : UIColor(hex: "F8F8FA")
        })
        static let secondaryBackground = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "0D0D0D") : UIColor(hex: "FFFFFF")
        })
        static let tertiaryBackground = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "131313") : UIColor(hex: "F5F5F7")
        })

        // MARK: - Adaptive Text Colors
        static let primaryText = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "FFFFFF") : UIColor(hex: "000000")
        })
        static let secondaryText = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "B3B3B3") : UIColor(hex: "6B7280")
        })
        static let tertiaryText = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "666666") : UIColor(hex: "9CA3AF")
        })
        static let disabledText = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "333333") : UIColor(hex: "D1D5DB")
        })

        // MARK: - Adaptive Card Colors
        static let cardBackground = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "0D0D0D") : UIColor(hex: "FFFFFF")
        })
        static let cardBackgroundElevated = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: "131313") : UIColor(hex: "FAFAFA")
        })
        static let cardShadow = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor.black.withAlphaComponent(0.3) : UIColor.black.withAlphaComponent(0.08)
        })

        // Glow Effects
        static let glowBlue = Color(hex: "3C82F6").opacity(0.15) // Subtle blue glow
        static let glowBlueStrong = Color(hex: "3C82F6").opacity(0.2) // Stronger glow

        // MARK: - Clara AI Colors
        static let claraPurple = Color(hex: "8B5CF6")
        static let claraPurpleLight = Color(hex: "A855F7")
        static let claraPurpleDark = Color(hex: "7C3AED")

        static let claraGradient = LinearGradient(
            colors: [claraPurple, claraPurpleLight, claraPurpleDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let claraGradientSimple = LinearGradient(
            colors: [claraPurple, claraPurpleLight],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // MARK: - Semantic Colors (for alerts, status, buttons)
        static let warningYellow = Color(hex: "F59E0B")
        static let warningYellowDark = Color(hex: "D97706")
        static let errorRed = Color(hex: "EF4444")
        static let errorRedDark = Color(hex: "DC2626")
        static let successGreen = Color(hex: "10B981")
        static let successGreenDark = Color(hex: "059669")

        // Indigo (for balanced/neutral states)
        static let indigo = Color(hex: "6366F1")
        static let indigoDark = Color(hex: "4F46E5")

        // MARK: - Semantic Aliases (use these throughout the app)
        static let amber = warningYellow           // Task/suggestion accent
        static let amberDark = warningYellowDark
        static let emerald = successGreen          // Success/completion
        static let emeraldDark = successGreenDark
        static let violet = claraPurple            // Clara AI / Rest
        static let violetDark = claraPurpleDark
        static let blue = primary                  // Focus / Primary action
        static let blueDark = primaryDark

        // MARK: - Semantic Gradients
        static let warningGradient = LinearGradient(
            colors: [warningYellow, warningYellowDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let errorGradient = LinearGradient(
            colors: [errorRed, errorRedDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let successGradient = LinearGradient(
            colors: [successGreen, successGreenDark],
            startPoint: .leading,
            endPoint: .trailing
        )

        static let indigoGradient = LinearGradient(
            colors: [indigo, indigoDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        // Gradients
        static let primaryGradient = LinearGradient(
            colors: [primary, primaryDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let accentGradient = LinearGradient(
            colors: [accent, Color(hex: "FF8787")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let backgroundGradient = LinearGradient(
            colors: [Color(UIColor.systemBackground), Color(UIColor.secondarySystemBackground)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Typography - Apple-Style Clean Typography with Dynamic Type Support
    struct Typography {
        // Display - Large titles that scale with user preferences
        static let largeTitle = Font.largeTitle.weight(.thin)
        static let title1 = Font.title.weight(.thin)
        static let title2 = Font.title2.weight(.light)
        static let title3 = Font.title3.weight(.light)

        // Section Headers - Medium-weight, scales with user preferences
        static let sectionHeader = Font.headline

        // Body - Regular-weight, scales with user preferences
        static let body = Font.body
        static let bodyBold = Font.body.weight(.semibold)
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Spacing - Generous and Elegant
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24 // Standard section spacing
        static let xl: CGFloat = 32 // Large section spacing
        static let xxl: CGFloat = 48
        
        // Margins
        static let screenMargin: CGFloat = 20 // Standard screen margin (20-24pt)
        static let screenMarginLarge: CGFloat = 24
    }
    
    // MARK: - Corner Radius - Official Chrona Theme
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16 // Standard card radius
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24 // Large tile radius (Today tiles)
        static let button: CGFloat = 16 // Button radius (16pt+)
        static let full: CGFloat = 999
    }

    // MARK: - Today Screen Specific Layout
    struct Today {
        static let cardPadding: CGFloat = 16
        static let cardPaddingLarge: CGFloat = 20
        static let tileCornerRadius: CGFloat = 24
        static let innerCardCornerRadius: CGFloat = 18
        static let tileMinHeight: CGFloat = 140
        static let tileSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 16
    }

    // MARK: - Component Sizes (Standard Tokens)
    struct Components {
        // Avatar sizes
        static let avatarSmall: CGFloat = 28
        static let avatarMedium: CGFloat = 32
        static let avatarLarge: CGFloat = 44
        static let avatarXLarge: CGFloat = 72

        // Icon sizes
        static let iconSmall: CGFloat = 12
        static let iconMedium: CGFloat = 14
        static let iconLarge: CGFloat = 18
        static let iconXLarge: CGFloat = 24
        static let iconXXLarge: CGFloat = 32

        // Touch targets (minimum 44pt for accessibility)
        static let minTouchTarget: CGFloat = 44
        static let buttonHeight: CGFloat = 52
        static let compactButtonHeight: CGFloat = 44

        // Chat bubble specific
        static let chatBubbleRadius: CGFloat = 18
        static let chatBubblePadding: CGFloat = 14
        static let chatAvatarSize: CGFloat = 32

        // Input field
        static let inputFieldRadius: CGFloat = 24
        static let inputFieldPadding: CGFloat = 14
    }

    // MARK: - Font Sizes (for cases where system fonts don't work)
    struct FontSize {
        static let xs: CGFloat = 11
        static let sm: CGFloat = 13
        static let md: CGFloat = 15
        static let lg: CGFloat = 17
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let small = ShadowStyle(
            color: Colors.cardShadow,
            radius: 4,
            x: 0,
            y: 2
        )
        
        static let medium = ShadowStyle(
            color: Colors.cardShadow,
            radius: 8,
            x: 0,
            y: 4
        )
        
        static let large = ShadowStyle(
            color: Colors.cardShadow,
            radius: 16,
            x: 0,
            y: 8
        )
    }
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Materials (iOS 18 Glassy Effects)
    struct Materials {
        // Frosted glass materials
        static let tabBarMaterial = Material.ultraThinMaterial
        static let cardMaterial = Material.thinMaterial
        static let modalMaterial = Material.regularMaterial
        
        // Vibrancy effects
        static let vibrantTabBar = Material.ultraThinMaterial
        static let vibrantCard = Material.thinMaterial
    }
    
    // MARK: - Animations
    struct Animations {
        static let quick = Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)
        static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
        static let gentle = Animation.easeInOut(duration: 0.3)
    }
}

// MARK: - Day Mood Type (Centralized mood color/gradient/icon mapping)
enum DayMood: String, CaseIterable {
    case focusDay = "focus_day"
    case lightDay = "light_day"
    case intenseMeetings = "intense_meetings"
    case restDay = "rest_day"
    case balanced = "balanced"
    case unknown = ""

    init(from string: String?) {
        switch (string ?? "").lowercased() {
        case "focus_day", "focused": self = .focusDay
        case "light_day", "light": self = .lightDay
        case "intense_meetings", "intense", "busy", "busy_day": self = .intenseMeetings
        case "rest_day", "rest": self = .restDay
        case "balanced": self = .balanced
        default: self = .unknown
        }
    }

    var color: Color {
        switch self {
        case .focusDay: return DesignSystem.Colors.primary
        case .lightDay: return DesignSystem.Colors.successGreen
        case .intenseMeetings: return DesignSystem.Colors.warningYellow
        case .restDay: return DesignSystem.Colors.claraPurple
        case .balanced: return DesignSystem.Colors.indigo
        case .unknown: return DesignSystem.Colors.primary
        }
    }

    var colorDark: Color {
        switch self {
        case .focusDay: return DesignSystem.Colors.primaryDark
        case .lightDay: return DesignSystem.Colors.successGreenDark
        case .intenseMeetings: return DesignSystem.Colors.warningYellowDark
        case .restDay: return DesignSystem.Colors.claraPurpleDark
        case .balanced: return DesignSystem.Colors.indigoDark
        case .unknown: return DesignSystem.Colors.primaryDark
        }
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [color, colorDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var icon: String {
        switch self {
        case .focusDay: return "brain.head.profile"
        case .lightDay: return "sun.max.fill"
        case .intenseMeetings: return "flame.fill"
        case .restDay: return "leaf.fill"
        case .balanced: return "scale.3d"
        case .unknown: return "sparkles"
        }
    }

    var label: String {
        switch self {
        case .focusDay: return "Focus Day"
        case .lightDay: return "Light Day"
        case .intenseMeetings: return "Busy Day"
        case .restDay: return "Rest Day"
        case .balanced: return "Balanced Day"
        case .unknown: return "Your Day"
        }
    }
}

// MARK: - Unified Button Styles
struct ScaleButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct FABButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UIColor Extension for Hex (needed for adaptive colors)
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

    // MARK: - View Extensions for Design System
extension View {
    // Chrona Dark Theme Card Style
    func chronaCard(padding: CGFloat = DesignSystem.Spacing.md, elevated: Bool = false) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(elevated ? DesignSystem.Colors.cardBackgroundElevated : DesignSystem.Colors.cardBackground)
            )
            .shadow(
                color: DesignSystem.Colors.cardShadow,
                radius: elevated ? 12 : 8,
                x: 0,
                y: elevated ? 6 : 4
            )
    }
    
    // Primary Button - Full-width, blue background
    func chronaPrimaryButton(isEnabled: Bool = true) -> some View {
        self
            .font(DesignSystem.Typography.bodyBold)
            .foregroundColor(DesignSystem.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52) // 52pt+ height
            .background(
                isEnabled ? DesignSystem.Colors.primary : DesignSystem.Colors.disabledText
            )
            .cornerRadius(DesignSystem.CornerRadius.button)
            .shadow(
                color: isEnabled ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear,
                radius: 12,
                x: 0,
                y: 6
            )
    }
    
    // Secondary Button - Transparent with white border
    func chronaSecondaryButton() -> some View {
        self
            .font(DesignSystem.Typography.bodyBold)
            .foregroundColor(DesignSystem.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                    .stroke(DesignSystem.Colors.primaryText.opacity(0.25), lineWidth: 1.5)
            )
    }
    
    // Subtle glow effect for important elements
    func chronaGlow(color: Color = DesignSystem.Colors.primary, opacity: Double = 0.15) -> some View {
        self
            .shadow(color: color.opacity(opacity), radius: 20, x: 0, y: 0)
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self // Disabled for performance - can be re-enabled later
    }

    // Today Overview Sheet Card Style (consistent section cards)
    func cardStyle(padding: CGFloat = DesignSystem.Today.cardPadding) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Today.innerCardCornerRadius)
                    .fill(DesignSystem.Colors.cardBackground)
            )
    }

    // Today Overview Section Card Style (for sections like Key Metrics, AI Summary)
    func sectionCardStyle() -> some View {
        self
            .padding(DesignSystem.Today.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Today.innerCardCornerRadius)
                    .fill(DesignSystem.Colors.cardBackground)
            )
    }

    // MARK: - Calm UI Card Style (premium, relaxed feel)
    func calmCard(padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.calmBorder, lineWidth: 0.5)
            )
    }

    // Calm Hero Card Style (for primary summary card)
    func heroCard() -> some View {
        self
            .padding(DesignSystem.Today.cardPaddingLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Today.tileCornerRadius)
                    .fill(DesignSystem.Colors.heroGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Today.tileCornerRadius)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
    }

    // Calm Insights Preview Card Style
    func insightsCard() -> some View {
        self
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.insightsGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
    }
}


