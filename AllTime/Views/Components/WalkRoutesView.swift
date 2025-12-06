import SwiftUI

struct WalkRoutesView: View {
    let walkRoutes: WalkRoutes
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "figure.walk.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Walk Recommendations")
                        .font(.title3.weight(.bold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                    
                    Text(walkRoutes.healthBenefit)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
                
                Spacer()
            }
            
            // Stats
            HStack(spacing: DesignSystem.Spacing.md) {
                WalkStatBadge(icon: "clock", value: "\(walkRoutes.durationMinutes) min")
                WalkStatBadge(icon: "map", value: String(format: "%.1f km", walkRoutes.distanceKm))
                if let suggestedTime = walkRoutes.suggestedTime {
                    WalkStatBadge(icon: "calendar.badge.clock", value: suggestedTime)
                }
            }
            
            // Routes
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(walkRoutes.routes) { route in
                    WalkRouteCard(route: route)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

struct WalkStatBadge: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
        }
        .foregroundColor(DesignSystem.Colors.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.1))
        .cornerRadius(6)
    }
}

struct WalkRouteCard: View {
    let route: WalkRoute
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Text(route.name)
                    .font(.body.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Spacer()
                difficultyBadge
            }
            
            if let description = route.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Stats
            HStack(spacing: DesignSystem.Spacing.md) {
                RouteStatItem(icon: "map", value: String(format: "%.1f km", route.distanceKm))
                RouteStatItem(icon: "clock", value: "\(route.durationMinutes) min")
                if let elevation = route.elevationGain, elevation > 0 {
                    RouteStatItem(icon: "arrow.up.right", value: String(format: "%.0fm", elevation))
                }
            }
            
            // Highlights
            if let highlights = route.highlights, !highlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(highlights, id: \.self) { highlight in
                            Text(highlight)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Navigate button
            Button {
                openRoute()
            } label: {
                HStack {
                    Image(systemName: "map.fill")
                    Text("Start Walk in Maps")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
    
    private var difficultyBadge: some View {
        let difficulty = route.difficulty ?? "unknown"
        let color: Color = {
            switch difficulty.lowercased() {
            case "easy": return .green
            case "moderate": return .orange
            case "challenging", "hard": return .red
            default: return .gray
            }
        }()
        
        return Text(difficulty.capitalized)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    private func openRoute() {
        guard let mapUrl = route.mapUrl, let url = URL(string: mapUrl) else { return }
        UIApplication.shared.open(url)
    }
}

struct RouteStatItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
        }
        .foregroundColor(DesignSystem.Colors.tertiaryText)
    }
}

