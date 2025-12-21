import SwiftUI

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


