import SwiftUI

struct OnDemandFoodView: View {
    @ObservedObject var viewModel: OnDemandRecommendationsViewModel
    @State private var selectedCategory: FoodCategory = .all
    @State private var searchRadius: Double = 1.5
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Refresh Button
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("🍽️ Food Options")
                            .font(.title2)
                            .bold()
                        
                        Text("Find nearby food options anytime")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await viewModel.refreshFood(category: selectedCategory.rawValue, radius: searchRadius)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .rotationEffect(.degrees(viewModel.isLoading ? 360 : 0))
                            .animation(
                                viewModel.isLoading ? 
                                    Animation.linear(duration: 1).repeatForever(autoreverses: false) : 
                                    .default,
                                value: viewModel.isLoading
                            )
                    }
                    .disabled(viewModel.isLoading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Category Filter
                Picker("Category", selection: $selectedCategory) {
                    ForEach(FoodCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedCategory) { newValue in
                    Task {
                        await viewModel.refreshFood(category: newValue.rawValue, radius: searchRadius)
                    }
                }
                
                // Radius Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Search Radius: \(String(format: "%.1f", searchRadius.kmToMiles)) miles")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(String(format: "%.1f", searchRadius)) km")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Slider(value: $searchRadius, in: 0.5...5.0, step: 0.5)
                        .onChange(of: searchRadius) { _ in
                            Task {
                                await viewModel.refreshFood(category: selectedCategory.rawValue, radius: searchRadius)
                            }
                        }
                    
                    HStack {
                        Text("0.3 mi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("3.1 mi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Healthy Options
                if !viewModel.healthyOptions.isEmpty && 
                   (selectedCategory == .all || selectedCategory == .healthy) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Healthy Options", systemImage: "leaf.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        ForEach(viewModel.healthyOptions) { spot in
                            FoodSpotCard(spot: spot, isHealthy: true)
                        }
                    }
                }
                
                // Regular Options
                if !viewModel.regularOptions.isEmpty && 
                   (selectedCategory == .all || selectedCategory == .regular) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Regular Options", systemImage: "fork.knife")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(viewModel.regularOptions) { spot in
                            FoodSpotCard(spot: spot, isHealthy: false)
                        }
                    }
                }
                
                // Empty State
                if viewModel.healthyOptions.isEmpty && viewModel.regularOptions.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No food options found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try adjusting your search radius")
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
            await viewModel.refreshFood(category: selectedCategory.rawValue, radius: searchRadius)
        }
    }
}

struct FoodSpotCard: View {
    let spot: FoodSpot
    let isHealthy: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon/Photo placeholder
            ZStack {
                Circle()
                    .fill(isHealthy ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Text(isHealthy ? "🥗" : "🍕")
                    .font(.title2)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(spot.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if isHealthy {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                // Rating, price, cuisine
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
                            .lineLimit(1)
                    }
                }
                
                // Distance
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(spot.walkingMinutes) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f km", spot.distanceKm))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Dietary tags
                if let tags = spot.dietaryTags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(tags.prefix(3), id: \.self) { tag in
                                Text(tag)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "arrow.right.circle.fill")
                .foregroundColor(isHealthy ? .green : .orange)
                .font(.title3)
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

