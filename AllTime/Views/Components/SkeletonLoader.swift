import SwiftUI

// MARK: - Shimmer Effect

/// A shimmer animation modifier for skeleton loading states
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2) * phase)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Views

/// A skeleton placeholder view that shimmers while loading
struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
            .shimmer()
    }
}

/// Skeleton for event cards
struct EventCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemGray5))
                .frame(width: 4, height: 50)
                .shimmer()

            VStack(alignment: .leading, spacing: 8) {
                // Title
                SkeletonView(width: 180, height: 16, cornerRadius: 4)

                // Time
                SkeletonView(width: 100, height: 12, cornerRadius: 4)
            }

            Spacer()

            // Icon
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 32, height: 32)
                .shimmer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

/// Skeleton for daily briefing
struct BriefingSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                SkeletonView(width: 140, height: 24, cornerRadius: 6)
                Spacer()
                SkeletonView(width: 60, height: 20, cornerRadius: 4)
            }

            // Summary lines
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 14, cornerRadius: 4)
                SkeletonView(width: 280, height: 14, cornerRadius: 4)
                SkeletonView(width: 200, height: 14, cornerRadius: 4)
            }

            // Stats row
            HStack(spacing: 16) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 4) {
                        SkeletonView(width: 40, height: 24, cornerRadius: 4)
                        SkeletonView(width: 60, height: 12, cornerRadius: 4)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

/// Skeleton for insights card
struct InsightsCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 28, height: 28)
                    .shimmer()

                SkeletonView(width: 120, height: 18, cornerRadius: 4)
                Spacer()
            }

            // Content
            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(height: 14, cornerRadius: 4)
                SkeletonView(width: 240, height: 14, cornerRadius: 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

/// Skeleton for list items
struct ListItemSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
                .shimmer()

            VStack(alignment: .leading, spacing: 6) {
                SkeletonView(width: 160, height: 16, cornerRadius: 4)
                SkeletonView(width: 100, height: 12, cornerRadius: 4)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Loading State Container

/// A container that shows skeleton or content based on loading state
struct LoadingContainer<Content: View, Skeleton: View>: View {
    let isLoading: Bool
    let content: () -> Content
    let skeleton: () -> Skeleton

    init(
        isLoading: Bool,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder skeleton: @escaping () -> Skeleton
    ) {
        self.isLoading = isLoading
        self.content = content
        self.skeleton = skeleton
    }

    var body: some View {
        ZStack {
            if isLoading {
                skeleton()
                    .transition(.opacity)
            } else {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }
}

// MARK: - Previews

#Preview("Event Card Skeleton") {
    VStack(spacing: 12) {
        EventCardSkeleton()
        EventCardSkeleton()
        EventCardSkeleton()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Briefing Skeleton") {
    BriefingSkeleton()
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("List Item Skeleton") {
    VStack(spacing: 0) {
        ListItemSkeleton()
        Divider()
        ListItemSkeleton()
        Divider()
        ListItemSkeleton()
    }
    .padding()
    .background(Color(.systemBackground))
}
