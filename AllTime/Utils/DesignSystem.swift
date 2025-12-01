import SwiftUI

// MARK: - Chrona Official Dark Theme Design System
struct DesignSystem {
    
    // MARK: - Colors - Official Chrona Dark Theme
    struct Colors {
        // Primary Accent - Chrona Icon Blue
        static let primary = Color(hex: "3C82F6") // Official Chrona blue
        static let primaryDark = Color(hex: "2563EB")
        static let primaryLight = Color(hex: "60A5FA")
        
        // Accent Colors
        static let accent = Color(hex: "FF6B6B")
        static let success = Color(hex: "34C759") // iOS Green
        static let warning = Color(hex: "FF9500") // iOS Orange
        static let info = Color(hex: "5AC8FA") // iOS Cyan
        
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
        
        // Background Colors - Pure Black Theme
        static let background = Color(hex: "000000") // Pure black
        static let backgroundLifted = Color(hex: "050505") // Slightly lifted black
        static let backgroundLifted2 = Color(hex: "0A0A0A") // More lifted black
        static let secondaryBackground = Color(hex: "0D0D0D") // Card background
        static let tertiaryBackground = Color(hex: "131313") // Elevated card background
        
        // Text Colors - Official Dark Theme
        static let primaryText = Color(hex: "FFFFFF") // Pure white
        static let secondaryText = Color(hex: "B3B3B3") // Secondary gray
        static let tertiaryText = Color(hex: "666666") // Tertiary gray (low contrast)
        static let disabledText = Color(hex: "333333") // Disabled text
        
        // Card Colors
        static let cardBackground = Color(hex: "0D0D0D")
        static let cardBackgroundElevated = Color(hex: "131313")
        static let cardShadow = Color.black.opacity(0.3)
        
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
    
    // MARK: - Typography - Apple-Style Clean Typography
    struct Typography {
        // Display - Large, thin-weight SF Pro Display style
        static let largeTitle = Font.system(size: 34, weight: .thin, design: .default)
        static let title1 = Font.system(size: 28, weight: .thin, design: .default)
        static let title2 = Font.system(size: 22, weight: .light, design: .default)
        static let title3 = Font.system(size: 20, weight: .light, design: .default)
        
        // Section Headers - Medium-weight SF Pro
        static let sectionHeader = Font.system(size: 17, weight: .medium, design: .default)
        
        // Body - Regular-weight SF Pro
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
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
        static let xxl: CGFloat = 22 // Maximum card radius
        static let button: CGFloat = 16 // Button radius (16pt+)
        static let full: CGFloat = 999
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
}


