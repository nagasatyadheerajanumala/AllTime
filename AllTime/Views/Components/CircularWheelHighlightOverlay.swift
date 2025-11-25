import SwiftUI

/// Center highlight overlay showing the selection area
struct CircularWheelHighlightOverlay: View {
    let containerSize: CGFloat
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            // Bottom center highlight area (where dates get selected)
            VStack {
                Spacer()
                
                // Highlight indicator (top center)
                ZStack {
                    // Glowing background
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.3),
                                    Color.blue.opacity(0.2)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60, height: 60)
                        .blur(radius: 15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.2)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                    
                    // Center dot
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .shadow(color: .white.opacity(0.5), radius: 4)
                }
                .offset(y: -radius - 30)
            }
            
            // Subtle radial gradient overlay for depth
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: radius * 0.5,
                        endRadius: radius * 1.5
                    )
                )
                .frame(width: containerSize, height: containerSize)
        }
    }
}

