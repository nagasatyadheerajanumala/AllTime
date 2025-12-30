import SwiftUI
import MapKit
import Combine

// MARK: - Meeting Spots Section (for TodayView)

struct MeetingSpotsSection: View {
    @StateObject private var viewModel = MeetingSpotsViewModel()
    @State private var showAllSpots = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.recommendations == nil {
                // Initial loading - show nothing (don't clutter the UI)
                EmptyView()
            } else if let recs = viewModel.recommendations, recs.hasMeetingWithLocation {
                meetingSpotCard(recs)
            }
            // If no meeting with location, show nothing
        }
        .task {
            await viewModel.fetchSpots()
        }
    }

    // MARK: - Meeting Spot Card

    @ViewBuilder
    private func meetingSpotCard(_ recs: MeetingSpotRecommendations) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with meeting context
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(recs.contextMessage ?? "Spots Near Your Meeting")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(DesignSystem.Colors.primaryText)

                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(recs.meetingLocation ?? "")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                Spacer()

                // Meeting time badge
                if let time = recs.meetingTime {
                    Text(time)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
            }

            // Spots preview (show first 2-3)
            if let spots = recs.spots, !spots.isEmpty {
                VStack(spacing: 8) {
                    ForEach(spots.prefix(2)) { spot in
                        SpotRow(spot: spot)
                    }

                    if spots.count > 2 {
                        Button(action: { showAllSpots = true }) {
                            HStack {
                                Text("View all \(spots.count) spots")
                                    .font(.caption.weight(.medium))
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                            }
                            .foregroundColor(DesignSystem.Colors.primary)
                        }
                        .padding(.top, 4)
                    }
                }
            } else {
                Text("No spots found nearby")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.secondaryText)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showAllSpots) {
            if let recs = viewModel.recommendations {
                MeetingSpotsDetailView(recommendations: recs)
            }
        }
    }
}

// MARK: - Spot Row

struct SpotRow: View {
    let spot: NearbySpot

    var body: some View {
        HStack(spacing: 12) {
            // Spot icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: spotIcon)
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
            }

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(DesignSystem.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if !spot.displayDistance.isEmpty {
                        Text(spot.displayDistance)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }

                    if let rating = spot.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", rating))
                                .font(.caption)
                                .foregroundColor(DesignSystem.Colors.secondaryText)
                        }
                    }

                    if let priceLevel = spot.priceLevelDisplay {
                        Text(priceLevel)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                    }
                }
            }

            Spacer()

            // Open indicator
            if spot.openNow == true {
                Text("Open")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            openInMaps()
        }
    }

    private var spotIcon: String {
        switch spot.primaryType {
        case "restaurant": return "fork.knife"
        case "cafe": return "cup.and.saucer.fill"
        case "bar": return "wineglass.fill"
        default: return "mappin"
        }
    }

    private func openInMaps() {
        guard let lat = spot.latitude, let lng = spot.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - Meeting Spots Detail View

struct MeetingSpotsDetailView: View {
    let recommendations: MeetingSpotRecommendations
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    // Meeting context header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recommendations.contextMessage ?? "Spots Near Your Meeting")
                            .font(.title3.weight(.bold))

                        if let location = recommendations.meetingLocation {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.orange)
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }

                        if let title = recommendations.meetingTitle, let time = recommendations.meetingTime {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                                Text("\(title) at \(time)")
                                    .font(.subheadline)
                                    .foregroundColor(DesignSystem.Colors.secondaryText)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.md)

                    // All spots
                    if let spots = recommendations.spots {
                        ForEach(spots) { spot in
                            SpotDetailCard(spot: spot)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Spots Near Meeting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Spot Detail Card

struct SpotDetailCard: View {
    let spot: NearbySpot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(spot.name)
                        .font(.headline)

                    if let address = spot.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.secondaryText)
                            .lineLimit(2)
                    }
                }

                Spacer()

                if spot.openNow == true {
                    Text("Open")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            HStack(spacing: 16) {
                if !spot.displayDistance.isEmpty {
                    Label(spot.displayDistance, systemImage: "figure.walk")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                if !spot.displayWalkingTime.isEmpty {
                    Text(spot.displayWalkingTime)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }

                if let rating = spot.rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", rating))
                        if let total = spot.userRatingsTotal {
                            Text("(\(total))")
                                .foregroundColor(DesignSystem.Colors.tertiaryText)
                        }
                    }
                    .font(.caption)
                }

                if let priceLevel = spot.priceLevelDisplay {
                    Text(priceLevel)
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.secondaryText)
                }
            }

            // Directions button
            Button(action: openInMaps) {
                HStack {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    Text("Get Directions")
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.cardBackground)
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: 2)
        )
    }

    private func openInMaps() {
        guard let lat = spot.latitude, let lng = spot.longitude else { return }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = spot.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}

// MARK: - ViewModel

@MainActor
class MeetingSpotsViewModel: ObservableObject {
    @Published var recommendations: MeetingSpotRecommendations?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let apiService = APIService()

    func fetchSpots() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        do {
            recommendations = try await apiService.getMeetingSpotRecommendations()
        } catch {
            print("❌ MeetingSpotsViewModel: Failed to fetch spots: \(error)")
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    VStack {
        MeetingSpotsSection()
    }
    .padding()
    .background(DesignSystem.Colors.background)
}
