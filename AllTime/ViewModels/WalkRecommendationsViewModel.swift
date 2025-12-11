import Foundation
import Combine
import CoreLocation

@MainActor
class WalkRecommendationsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var walkRoutes: [WalkRouteRecommendation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userLocation: String?
    @Published var healthBenefit: String?
    @Published var locationPermissionNeeded = false

    // Filter states
    @Published var selectedDifficulty: WalkDifficulty = .moderate
    @Published var targetDistanceMiles: Double = 1.0

    // Available duration options (in minutes)
    let durationOptions = [10, 15, 20, 30, 45, 60]
    @Published var selectedDuration: Int = 20

    // MARK: - Private Properties
    private let apiService = APIService()
    private let locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties
    var filteredWalkRoutes: [WalkRouteRecommendation] {
        walkRoutes.filter { route in
            // Filter by distance
            guard let distanceKm = route.distanceKm else { return true }
            let distanceMiles = distanceKm * 0.621371
            // Allow routes within 50% of target distance
            let minDistance = targetDistanceMiles * 0.5
            let maxDistance = targetDistanceMiles * 1.5
            return distanceMiles >= minDistance && distanceMiles <= maxDistance
        }
    }

    var hasResults: Bool {
        !filteredWalkRoutes.isEmpty
    }

    // MARK: - Public Methods
    func loadRecommendations() async {
        isLoading = true
        errorMessage = nil
        locationPermissionNeeded = false

        // Get current location
        let latitude = locationManager.location?.coordinate.latitude
        let longitude = locationManager.location?.coordinate.longitude

        // Check if we need location permission
        if latitude == nil || longitude == nil {
            if locationManager.authorizationStatus == .notDetermined {
                locationPermissionNeeded = true
                locationManager.requestLocationPermission()
                // Wait a bit for location
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        do {
            let response = try await apiService.getWalkRecommendations(
                distanceMiles: targetDistanceMiles,
                difficulty: selectedDifficulty.rawValue,
                latitude: locationManager.location?.coordinate.latitude,
                longitude: locationManager.location?.coordinate.longitude
            )

            walkRoutes = response.routes ?? []
            userLocation = response.userLocation
            healthBenefit = response.healthBenefit

            isLoading = false
        } catch {
            print("Error loading walk recommendations: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func refreshRecommendations() async {
        await loadRecommendations()
    }

    func updateDifficulty(_ difficulty: WalkDifficulty) {
        selectedDifficulty = difficulty
        Task {
            await loadRecommendations()
        }
    }

    func updateTargetDistance(_ miles: Double) {
        targetDistanceMiles = miles
    }

    func updateDuration(_ minutes: Int) {
        selectedDuration = minutes
        // Estimate distance based on duration (avg walking speed ~3mph)
        targetDistanceMiles = Double(minutes) / 20.0
        Task {
            await loadRecommendations()
        }
    }
}
