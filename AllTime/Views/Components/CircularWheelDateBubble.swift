import SwiftUI

/// Individual date bubble in the circular wheel with glass-morphism
struct CircularWheelDateBubble: View {
    let date: Date
    let dayNumber: Int
    let isToday: Bool
    let isSelected: Bool
    let hasEvents: Bool
    let position: CGPoint
    let size: CGFloat
    let rotation: Double // Wheel rotation to counter-rotate text
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Glass-morphism bubble
                Circle()
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.8),
                                        Color.blue.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(.ultraThinMaterial)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected 
                                    ? LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.6),
                                            Color.white.opacity(0.3)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                lineWidth: isSelected ? 3 : 1
                            )
                    )
                    .shadow(
                        color: isSelected 
                            ? Color.purple.opacity(0.5)
                            : Color.black.opacity(0.2),
                        radius: isSelected ? 12 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .blur(radius: isSelected ? 0 : 0.5)
                
                // Day number - counter-rotate to keep text upright
                Text("\(dayNumber)")
                    .font(.system(size: size * 0.4, weight: isSelected ? .bold : .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                    .rotationEffect(.radians(-rotation)) // Counter-rotate to keep text straight
                
                // Event indicator dots
                if hasEvents {
                    VStack {
                        Spacer()
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color.orange.opacity(0.9))
                                .frame(width: 4, height: 4)
                            if isSelected {
                                Circle()
                                    .fill(Color.orange.opacity(0.9))
                                    .frame(width: 4, height: 4)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.bottom, 4)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
            }
        }
        .offset(x: position.x, y: position.y)
        .scaleEffect(isSelected ? 1.3 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isSelected)
    }
}

