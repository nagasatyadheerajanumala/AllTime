import SwiftUI

// MARK: - Daily Summary Section
struct DailySummarySectionView: View {
    let items: [String]
    let title: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(DesignSystem.Colors.primary)
                        Text(item)
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Alerts Section
struct AlertsSectionView: View {
    let alerts: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚠️ Alerts")
                .font(.title3.weight(.bold))
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(alerts, id: \.self) { alert in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text(alert)
                            .font(.body)
                            .foregroundColor(DesignSystem.Colors.primaryText)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Health Suggestions
struct HealthSuggestionsView: View {
    let suggestions: [HealthBasedSuggestion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 Health Suggestions")
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            VStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    HealthSuggestionCard(suggestion: suggestion)
                }
            }
        }
    }
}

struct HealthSuggestionCard: View {
    let suggestion: HealthBasedSuggestion
    
    private var priorityColor: Color {
        switch suggestion.priority.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.type.capitalized)
                    .font(.headline)
                
                Spacer()
                
                Text(suggestion.priority.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor.opacity(0.2))
                    .foregroundColor(priorityColor)
                    .cornerRadius(4)
            }
            
            Text(suggestion.message)
                .font(.body)
                .foregroundColor(DesignSystem.Colors.secondaryText)
            
            if !suggestion.action.isEmpty {
                Text(suggestion.action)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Lunch Spots
struct LunchSpotsView: View {
    let lunch: LunchRecommendation
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🍽️ Lunch Spots")
                    .font(.title3.weight(.bold))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                
                Spacer()
                
                if let minutes = lunch.minutesUntilLunch {
                    Text("\(minutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let message = lunch.message, !message.isEmpty {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if let spots = lunch.nearbySpots, !spots.isEmpty {
                VStack(spacing: 8) {
                    ForEach(spots.prefix(3)) { spot in
                        LunchSpotCardCompact(spot: spot)
                    }
                }
            }
        }
    }
}

struct LunchSpotCardCompact: View {
    let spot: LunchSpot
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("🍽️")
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(spot.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    if let rating = spot.rating {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text(String(format: "%.1f", rating))
                            .font(.caption)
                    }
                    if let price = spot.priceLevel {
                        Text(price)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let cuisine = spot.cuisine {
                        Text("• \(cuisine)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text("\(spot.walkingMinutes) min walk • \(String(format: "%.1f km", spot.distanceKm))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(.orange)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            openInMaps()
        }
    }
    
    private func openInMaps() {
        let query = spot.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Walk Routes List
struct WalkRoutesListView: View {
    let routes: [WalkRoute]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🚶 Walk Routes")
                .font(.title3.weight(.bold))
                .foregroundColor(DesignSystem.Colors.primaryText)
            
            VStack(spacing: 8) {
                ForEach(routes.prefix(3)) { route in
                    WalkRouteCardCompact(route: route)
                }
            }
        }
    }
}

struct WalkRouteCardCompact: View {
    let route: WalkRoute
    
    private var difficultyColor: Color {
        guard let difficulty = route.difficulty else { return .blue }
        switch difficulty.lowercased() {
        case "easy": return .green
        case "moderate": return .orange
        case "challenging": return .red
        default: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(difficultyColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text("🚶")
                    .font(.title3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    if let difficulty = route.difficulty {
                        Text(difficulty.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(difficultyColor.opacity(0.2))
                            .foregroundColor(difficultyColor)
                            .cornerRadius(4)
                    }
                }
                
                if let description = route.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 12) {
                    Label("\(route.durationMinutes) min", systemImage: "clock")
                    Label(String(format: "%.1f km", route.distanceKm), systemImage: "figure.walk")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(difficultyColor)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            openInMaps()
        }
    }
    
    private func openInMaps() {
        guard let mapUrl = route.mapUrl, let url = URL(string: mapUrl) else { return }
        UIApplication.shared.open(url)
    }
}
