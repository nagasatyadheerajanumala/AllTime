import SwiftUI

// MARK: - Premium Design System
struct DesignSystem {
    
    // MARK: - Colors
    struct Colors {
        // Primary Brand Colors - Professional and clean
        static let primary = Color(hex: "007AFF") // iOS Blue - classic and professional
        static let primaryDark = Color(hex: "0051D5")
        static let primaryLight = Color(hex: "5AC8FA")
        
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
        
        // Background Colors
        static let background = Color(UIColor.systemBackground)
        static let secondaryBackground = Color(UIColor.secondarySystemBackground)
        static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)
        
        // Text Colors
        static let primaryText = Color(UIColor.label)
        static let secondaryText = Color(UIColor.secondaryLabel)
        static let tertiaryText = Color(UIColor.tertiaryLabel)
        
        // Card Colors
        static let cardBackground = Color(UIColor.systemBackground)
        static let cardShadow = Color.black.opacity(0.08)
        
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
    
    // MARK: - Typography - Clean and Professional
    struct Typography {
        // Display - Using system default for cleaner, more professional look
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .default)
        static let title1 = Font.system(size: 28, weight: .bold, design: .default)
        static let title2 = Font.system(size: 22, weight: .semibold, design: .default)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .default)
        
        // Body - Clean system fonts
        static let body = Font.system(size: 17, weight: .regular, design: .default)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .default)
        static let callout = Font.system(size: 16, weight: .regular, design: .default)
        static let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        static let footnote = Font.system(size: 13, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .regular, design: .default)
        static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius - Clean and Consistent
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24 // Reduced from 28 for cleaner look
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
    // Clean Professional Card Style
    func premiumCard(padding: CGFloat = DesignSystem.Spacing.md) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(Color(UIColor.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(
                        Color(UIColor.separator).opacity(0.3),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: Color.black.opacity(0.06),
                radius: 8,
                x: 0,
                y: 2
            )
            .shadow(
                color: Color.black.opacity(0.03),
                radius: 4,
                x: 0,
                y: 1
            )
    }
    
    func premiumButton(isEnabled: Bool = true) -> some View {
        self
            .font(DesignSystem.Typography.bodyBold)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(
                isEnabled ? DesignSystem.Colors.primaryGradient : LinearGradient(
                    colors: [Color.gray.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(
                color: isEnabled ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear,
                radius: 8,
                x: 0,
                y: 4
            )
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) -> some View {
        self // Disabled for performance - can be re-enabled later
    }
}


