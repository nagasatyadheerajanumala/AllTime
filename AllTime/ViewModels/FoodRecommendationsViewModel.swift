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
    @Published var backendMessage: String?

    // Filter states
    @Published var selectedCategory: FoodCategory = .all
    @Published var maxDistanceMiles: Double = 1.5
    @Published var searchRadiusKm: Double = 2.5

    // Dietary filters
    @Published var activeDietaryFilters: Set<DietaryFilter> = []
    @Published var activeDiningStyles: Set<DiningStyle> = []
    @Published var minRating: Double? = nil
    @Published var openNowOnly: Bool = false

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

        // Apply all filters
        return baseList.filter { spot in
            // Filter by distance
            if let distanceKm = spot.distanceKm {
                let distanceMiles = distanceKm * 0.621371
                if distanceMiles > maxDistanceMiles {
                    return false
                }
            }

            // Filter by dining style (OR logic - match ANY selected style)
            if !activeDiningStyles.isEmpty {
                let matchesAny = activeDiningStyles.contains { style in
                    spot.matchesDiningStyle(style)
                }
                if !matchesAny {
                    return false
                }
            }

            // Filter by dietary preferences
            for filter in activeDietaryFilters {
                if !spot.matchesDietaryFilter(filter) {
                    return false
                }
            }

            // Filter by minimum rating
            if let minRating = minRating, let rating = spot.rating {
                if rating < minRating {
                    return false
                }
            }

            // Filter by open now
            if openNowOnly && spot.openNow != true {
                return false
            }

            return true
        }
    }

    var hasResults: Bool {
        !filteredFoodSpots.isEmpty
    }

    var hasActiveFilters: Bool {
        !activeDietaryFilters.isEmpty || !activeDiningStyles.isEmpty || minRating != nil || openNowOnly
    }

    // Cached dietary filter results - updated when foodSpots changes
    @Published private(set) var veganSpots: [FoodSpot] = []
    @Published private(set) var vegetarianSpots: [FoodSpot] = []
    @Published private(set) var glutenFreeSpots: [FoodSpot] = []
    @Published private(set) var organicSpots: [FoodSpot] = []
    @Published private(set) var halalSpots: [FoodSpot] = []
    @Published private(set) var kosherSpots: [FoodSpot] = []

    private func updateDietaryFilters() {
        veganSpots = foodSpots.filter { $0.isVegan == true || $0.hasVeganOptions == true }
        vegetarianSpots = foodSpots.filter { ($0.isVegetarian == true || $0.hasVegetarianOptions == true) && $0.isVegan != true }
        glutenFreeSpots = foodSpots.filter { $0.isGlutenFree == true || $0.hasGlutenFreeOptions == true }
        organicSpots = foodSpots.filter { $0.isOrganic == true }
        halalSpots = foodSpots.filter { $0.isHalal == true }
        kosherSpots = foodSpots.filter { $0.isKosher == true }
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
            updateDietaryFilters()
            userLocation = response.userLocation

            if let radius = response.searchRadiusKm {
                searchRadiusKm = radius
            }

            // Capture backend message (for empty state display)
            backendMessage = response.message

            // If no results, log backend message
            if foodSpots.isEmpty {
                if let message = response.message, !message.isEmpty {
                    print("⚠️ FoodRecommendations: Backend message: \(message)")
                }
            }

            print("📍 FoodRecommendations: Location \(lat), \(lon) - Found \(foodSpots.count) spots")
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

    // MARK: - Dietary Filter Methods

    func toggleDietaryFilter(_ filter: DietaryFilter) {
        if activeDietaryFilters.contains(filter) {
            activeDietaryFilters.remove(filter)
        } else {
            activeDietaryFilters.insert(filter)
        }
    }

    func isDietaryFilterActive(_ filter: DietaryFilter) -> Bool {
        activeDietaryFilters.contains(filter)
    }

    func toggleDiningStyle(_ style: DiningStyle) {
        if activeDiningStyles.contains(style) {
            activeDiningStyles.remove(style)
        } else {
            activeDiningStyles.insert(style)
        }
    }

    func isDiningStyleActive(_ style: DiningStyle) -> Bool {
        activeDiningStyles.contains(style)
    }

    func clearAllFilters() {
        activeDietaryFilters.removeAll()
        activeDiningStyles.removeAll()
        minRating = nil
        openNowOnly = false
    }

    func setMinRating(_ rating: Double?) {
        minRating = rating
    }

    func toggleOpenNowOnly() {
        openNowOnly.toggle()
    }
}
