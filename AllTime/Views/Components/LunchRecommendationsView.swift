import SwiftUI

struct LunchRecommendationsView: View {
    let spots: [LunchPlace]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Lunch Recommendations")
                    .font(.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
            }
            
            // Nearby Spots
            if spots.isEmpty {
                EmptyLunchView()
            } else {
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(spots.prefix(5)) { spot in
                        LunchSpotCard(spot: spot)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

struct LunchSpotCard: View {
    let spot: LunchPlace
    
    var body: some View {
        Button {
            openInMaps()
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // Photo or icon placeholder
                ZStack {
                    LinearGradient(
                        colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Text("🍽️")
                        .font(.title)
                }
                .frame(width: 60, height: 60)
                .cornerRadius(10)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)
                        .lineLimit(2)
                    
                    // Rating, price, cuisine
                    HStack(spacing: 8) {
                        if let rating = spot.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                            }
                            .font(.caption)
                        }
                        
                        if let price = spot.priceLevel {
                            Text(price)
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                        
                        if let cuisine = spot.cuisine {
                            Text("• \(cuisine)")
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }
                    
                    // Distance and time
                    HStack(spacing: 8) {
                        if let minutes = spot.walkingMinutes {
                            Image(systemName: "figure.walk")
                                .font(.caption)
                            Text("\(minutes) min")
                                .font(.caption)
                        }
                        if let km = spot.distanceKm {
                            Text(String(format: "• %.1f km", km))
                                .font(.caption)
                        }
                        
                        if let open = spot.isOpenNow {
                            Spacer()
                            Text(open ? "Open" : "Closed")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(open ? .green : .red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(open ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    .foregroundColor(DesignSystem.Colors.tertiaryText)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .buttonStyle(.plain)
    }
    
    private func openInMaps() {
        let query = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let addressQuery = (spot.address ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(query)&address=\(addressQuery)") {
            UIApplication.shared.open(url)
        }
    }
}

struct EmptyLunchView: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "location.slash.circle")
                .font(.title2)
                .foregroundColor(DesignSystem.Colors.tertiaryText)
            VStack(alignment: .leading, spacing: 2) {
                Text("No nearby lunch spots found")
                    .font(.body.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                Text("Enable location services to see recommendations")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

