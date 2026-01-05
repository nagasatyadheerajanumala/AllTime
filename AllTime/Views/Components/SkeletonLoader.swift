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

// MARK: - Today View Skeletons

/// Skeleton for the Hero Summary Card on Today view
struct HeroCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Greeting line
            SkeletonView(width: 180, height: 28, cornerRadius: 8)

            // Summary text (2 lines)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonView(height: 16, cornerRadius: 4)
                SkeletonView(width: 260, height: 16, cornerRadius: 4)
            }

            // Stats row
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 16, height: 16)
                        SkeletonView(width: 50, height: 14, cornerRadius: 4)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xxl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.12, blue: 0.25),
                            Color(red: 0.1, green: 0.08, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shimmer()
    }
}

/// Skeleton for Up Next section
struct UpNextSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                SkeletonView(width: 80, height: 20, cornerRadius: 4)
                Spacer()
                SkeletonView(width: 60, height: 16, cornerRadius: 4)
            }

            // Event cards
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(width: 4, height: 50)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(width: 160, height: 16, cornerRadius: 4)
                        SkeletonView(width: 100, height: 12, cornerRadius: 4)
                    }

                    Spacer()

                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 28, height: 28)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
        .shimmer()
    }
}

/// Skeleton for Insights Preview Card
struct InsightsPreviewSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with score
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonView(width: 100, height: 14, cornerRadius: 4)
                    SkeletonView(width: 140, height: 20, cornerRadius: 4)
                }
                Spacer()
                // Score badge
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 48, height: 48)
            }

            // Capacity indicators
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 8, height: 8)
                        SkeletonView(width: 60, height: 12, cornerRadius: 4)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
        )
        .shimmer()
    }
}

// MARK: - Insights Tab Skeletons

/// Skeleton for Weekly Insights view
struct WeeklyInsightsSkeleton: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Balance score ring placeholder
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 12)
                        .frame(width: 140, height: 140)

                    VStack(spacing: 4) {
                        SkeletonView(width: 50, height: 36, cornerRadius: 8)
                        SkeletonView(width: 70, height: 14, cornerRadius: 4)
                    }
                }

                SkeletonView(width: 120, height: 16, cornerRadius: 4)
            }
            .padding(.top, DesignSystem.Spacing.md)

            // Trend indicator
            HStack {
                SkeletonView(width: 20, height: 20, cornerRadius: 4)
                SkeletonView(width: 100, height: 14, cornerRadius: 4)
            }

            // Metric cards (2x2 grid)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 32, height: 32)
                        SkeletonView(width: 80, height: 24, cornerRadius: 4)
                        SkeletonView(width: 60, height: 12, cornerRadius: 4)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
            }

            // Narrative section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 24, height: 24)
                    SkeletonView(width: 100, height: 18, cornerRadius: 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 14, cornerRadius: 4)
                    SkeletonView(height: 14, cornerRadius: 4)
                    SkeletonView(width: 200, height: 14, cornerRadius: 4)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .shimmer()
    }
}

/// Skeleton for Health Insights view
struct HealthInsightsSkeleton: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Date range picker placeholder
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonView(width: 90, height: 32, cornerRadius: 8)
                        .padding(.horizontal, 4)
                }
            }

            // Health narrative card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("💜").opacity(0.3)
                    SkeletonView(width: 130, height: 20, cornerRadius: 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonView(height: 14, cornerRadius: 4)
                    SkeletonView(height: 14, cornerRadius: 4)
                    SkeletonView(width: 220, height: 14, cornerRadius: 4)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.primary.opacity(0.1))
            )

            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        SkeletonView(width: 60, height: 24, cornerRadius: 4)
                        SkeletonView(width: 70, height: 12, cornerRadius: 4)
                    }
                    .padding(DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.cardBackground)
                    )
                }
            }

            // Insights cards
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(width: 140, height: 16, cornerRadius: 4)
                        SkeletonView(width: 200, height: 12, cornerRadius: 4)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .shimmer()
    }
}

/// Skeleton for Monthly/Life Insights view
struct MonthlyInsightsSkeleton: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Title
            SkeletonView(width: 180, height: 24, cornerRadius: 6)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Large stat card
            VStack(spacing: 12) {
                SkeletonView(width: 80, height: 48, cornerRadius: 8)
                SkeletonView(width: 100, height: 16, cornerRadius: 4)
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.cardBackground)
            )

            // Metric list
            ForEach(0..<4, id: \.self) { _ in
                HStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonView(width: 100, height: 16, cornerRadius: 4)
                        SkeletonView(width: 140, height: 12, cornerRadius: 4)
                    }

                    Spacer()

                    SkeletonView(width: 50, height: 20, cornerRadius: 4)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .shimmer()
    }
}

/// Skeleton for Food/Walk Recommendations
struct RecommendationsSkeleton: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                SkeletonView(width: 140, height: 22, cornerRadius: 4)
                Spacer()
                SkeletonView(width: 60, height: 16, cornerRadius: 4)
            }

            // Recommendation cards
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 6) {
                        SkeletonView(width: 140, height: 18, cornerRadius: 4)
                        SkeletonView(width: 100, height: 14, cornerRadius: 4)
                        HStack(spacing: 8) {
                            SkeletonView(width: 50, height: 12, cornerRadius: 4)
                            SkeletonView(width: 40, height: 12, cornerRadius: 4)
                        }
                    }

                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.cardBackground)
                )
            }
        }
        .shimmer()
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
