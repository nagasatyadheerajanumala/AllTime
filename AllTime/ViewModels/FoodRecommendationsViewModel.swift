import Foundation
import Combine
import CoreLocation

@MainActor
class FoodRecommendationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var foodSpots: [FoodSpot] = []
    @Published var healthyOptions: [FoodSpot] = []
    @Published var regularOptions: [FoodSpot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLocation: String?
    @Published var locationPermissionNeeded = false

    // Filter states
    @Published var selectedCategory: FoodCategory = .all
    @Published var maxDistanceMiles: Double = 1.5
    @Published var searchRadiusKm: Double = 2.5

    // MARK: - Private Properties
    private let apiService = APIService()
    private let locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var filteredFoodSpots: [FoodSpot] {
        let baseList: [FoodSpot]

        switch selectedCategory {
        case .all:
            baseList = foodSpots
        case .healthy:
            baseList = healthyOptions
        case .regular:
            baseList = regularOptions
        }

        // Filter by distance
        return baseList.filter { spot in
            guard let distanceKm = spot.distanceKm else { return true }
            let distanceMiles = distanceKm * 0.621371
            return distanceMiles <= maxDistanceMiles
        }
    }

    var hasResults: Bool {
        !filteredFoodSpots.isEmpty
    }

    // MARK: - Public Methods
    func loadRecommendations() async {
        isLoading = true
        errorMessage = nil
        locationPermissionNeeded = false

        // Get current location - REQUIRED for food recommendations
        var latitude = locationManager.location?.coordinate.latitude
        var longitude = locationManager.location?.coordinate.longitude

        // Check if we need location permission or if location is stale
        if latitude == nil || longitude == nil {
            if locationManager.authorizationStatus == .notDetermined {
                locationPermissionNeeded = true
                locationManager.requestLocationPermission()
            }

            // Request fresh location update
            locationManager.startLocationUpdates()

            // Wait for location to be available
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Try again after waiting
            latitude = locationManager.location?.coordinate.latitude
            longitude = locationManager.location?.coordinate.longitude
        }

        // If still no location, show error
        guard let lat = latitude, let lon = longitude else {
            errorMessage = "Location required for food recommendations. Please enable location services."
            isLoading = false
            locationPermissionNeeded = true
            return
        }

        do {
            // Pass radius_miles directly (no conversion needed)
            let response = try await apiService.getFoodRecommendations(
                radiusMiles: maxDistanceMiles,
                category: selectedCategory.rawValue,
                maxResults: 20,
                latitude: lat,
                longitude: lon
            )

            // Store the results
            healthyOptions = response.healthyOptions ?? []
            regularOptions = response.regularOptions ?? []

            // Combine all options and sort by distance
            var allSpots: [FoodSpot] = []
            allSpots.append(contentsOf: healthyOptions)
            allSpots.append(contentsOf: regularOptions)

            // Remove duplicates by name and sort by distance
            let uniqueSpots = Dictionary(grouping: allSpots, by: { $0.name })
                .compactMap { $0.value.first }
                .sorted { ($0.distanceKm ?? 999) < ($1.distanceKm ?? 999) }

            foodSpots = uniqueSpots
            userLocation = response.userLocation

            if let radius = response.searchRadiusKm {
                searchRadiusKm = radius
            }

            isLoading = false
        } catch {
            print("Error loading food recommendations: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func refreshRecommendations() async {
        await loadRecommendations()
    }

    func updateCategory(_ category: FoodCategory) {
        selectedCategory = category
    }

    func updateMaxDistance(_ miles: Double) {
        maxDistanceMiles = miles
    }
}
