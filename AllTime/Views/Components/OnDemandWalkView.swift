import SwiftUI

struct OnDemandWalkView: View {
    @ObservedObject var viewModel: OnDemandRecommendationsViewModel
    @State private var selectedDifficulty: WalkDifficulty = .easy
    @State private var distanceMiles: Double = 1.0
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("🚶 Walk Routes")
                        .font(.title2)
                        .bold()
                    
                    Text("Get personalized walking routes anytime")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Distance Slider (in MILES)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Distance: \(String(format: "%.1f", distanceMiles)) miles")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("~\(Int(distanceMiles * 20)) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $distanceMiles, in: 0.5...3.0, step: 0.5)
                        .onChange(of: distanceMiles) { _ in
                            Task {
                                await viewModel.refreshWalks(
                                    distanceMiles: distanceMiles,
                                    difficulty: selectedDifficulty.rawValue
                                )
                            }
                        }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("0.5 mi")
                                .font(.caption)
                            Text("~10 min")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("3.0 mi")
                                .font(.caption)
                            Text("~60 min")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Difficulty Picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Difficulty")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(WalkDifficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedDifficulty) { newValue in
                        Task {
                            await viewModel.refreshWalks(
                                distanceMiles: distanceMiles,
                                difficulty: newValue.rawValue
                            )
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Walk Routes
                if !viewModel.walkRoutes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(viewModel.walkRoutes.count) Routes Available")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        ForEach(viewModel.walkRoutes) { route in
                            OnDemandWalkRouteCard(route: route)
                        }
                    }
                }
                
                // Empty State
                if viewModel.walkRoutes.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.walk.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No walk routes found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try adjusting duration or difficulty")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            }
        }
        .task {
            await viewModel.refreshWalks(distanceMiles: distanceMiles, difficulty: selectedDifficulty.rawValue)
        }
    }
}

struct OnDemandWalkRouteCard: View {
    let route: OnDemandWalkRoute
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.headline)
                    
                    Text(route.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Difficulty badge
                Text(route.difficulty.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.2))
                    .foregroundColor(difficultyColor)
                    .cornerRadius(6)
            }
            
            // Stats
            HStack(spacing: 16) {
                StatItem(
                    icon: "figure.walk",
                    value: "\(route.estimatedMinutes) min",
                    label: "Duration"
                )
                
                StatItem(
                    icon: "arrow.left.and.right",
                    value: String(format: "%.1f km", route.distanceKm),
                    label: "Distance"
                )
                
                if route.elevationGain > 0 {
                    StatItem(
                        icon: "arrow.up.right",
                        value: String(format: "%.0fm", route.elevationGain),
                        label: "Elevation"
                    )
                }
            }
            
            // Highlights
            if !route.highlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(route.highlights.prefix(4), id: \.self) { highlight in
                            Text(highlight)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    openInGoogleMaps()
                } label: {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Google Maps")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                Button {
                    openInAppleMaps()
                } label: {
                    HStack {
                        Image(systemName: "map")
                        Text("Apple Maps")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var difficultyColor: Color {
        switch route.difficulty.lowercased() {
        case "easy": return .green
        case "moderate": return .orange
        case "challenging": return .red
        default: return .blue
        }
    }
    
    private func openInGoogleMaps() {
        guard let url = URL(string: route.mapUrl) else { return }
        UIApplication.shared.open(url)
    }
    
    private func openInAppleMaps() {
        guard let firstWaypoint = route.waypoints.first else { return }
        let query = route.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "http://maps.apple.com/?q=\(query)&ll=\(firstWaypoint.latitude),\(firstWaypoint.longitude)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

