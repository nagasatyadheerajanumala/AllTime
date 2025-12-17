import Foundation
import SwiftUI
import Combine

@MainActor
class PlanMyDayViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var selectedDate = Date()
    @Published var dayType: DayTypeInfo?
    @Published var suggestions: [ActivitySuggestion] = []
    @Published var itinerary: ItineraryResponse?

    @Published var isLoadingSuggestions = false
    @Published var isGeneratingItinerary = false
    @Published var errorMessage: String?
    @Published var needsInterestsSetup = false

    // Itinerary preferences
    @Published var pace: String = "balanced"
    @Published var includeMeals: Bool = true

    // MARK: - Computed Properties
    var isRestDay: Bool {
        dayType?.isRestDay ?? false
    }

    var dayTypeLabel: String {
        dayType?.dayTypeLabel ?? "Today"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Load Suggestions
    func loadSuggestions() async {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else { return }
        guard let token = KeychainManager.shared.getAccessToken() else {
            print("No access token available for loading suggestions")
            return
        }

        isLoadingSuggestions = true
        errorMessage = nil

        do {
            // Format date
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: selectedDate)

            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/planning/suggestions?date=\(dateString)") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }

            let suggestionsResponse = try JSONDecoder().decode(DaySuggestionsResponse.self, from: data)

            self.dayType = DayTypeInfo(
                date: suggestionsResponse.date,
                dayType: suggestionsResponse.dayType,
                dayTypeLabel: suggestionsResponse.dayTypeLabel,
                isWeekend: suggestionsResponse.dayType == "weekend",
                isHoliday: suggestionsResponse.dayType == "holiday",
                isRestDay: suggestionsResponse.isRestDay,
                holidayName: nil
            )

            self.suggestions = suggestionsResponse.suggestions ?? []
            self.needsInterestsSetup = suggestionsResponse.needsSetup ?? false

            print("Loaded \(suggestions.count) suggestions for \(dateString)")

        } catch {
            errorMessage = "Failed to load suggestions: \(error.localizedDescription)"
            print("Load suggestions error: \(error)")
        }

        isLoadingSuggestions = false
    }

    // MARK: - Generate Itinerary
    func generateItinerary() async {
        guard let userId = UserDefaults.standard.value(forKey: "userId") as? Int64 else { return }
        guard let token = KeychainManager.shared.getAccessToken() else {
            errorMessage = "Please sign in first"
            return
        }

        isGeneratingItinerary = true
        errorMessage = nil

        do {
            guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/planning/itinerary") else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(String(userId), forHTTPHeaderField: "X-User-ID")

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let dateString = formatter.string(from: selectedDate)

            let itineraryRequest = ItineraryRequest(
                startDate: dateString,
                endDate: dateString,
                preferences: ItineraryPreferences(
                    pace: pace,
                    includeMeals: includeMeals,
                    budget: "moderate"
                )
            )

            request.httpBody = try JSONEncoder().encode(itineraryRequest)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if let responseStr = String(data: data, encoding: .utf8) {
                    print("Generate itinerary failed: \(responseStr)")
                }
                throw URLError(.badServerResponse)
            }

            self.itinerary = try JSONDecoder().decode(ItineraryResponse.self, from: data)
            print("Generated itinerary with \(itinerary?.days.count ?? 0) days")

        } catch {
            errorMessage = "Failed to generate itinerary: \(error.localizedDescription)"
            print("Generate itinerary error: \(error)")
        }

        isGeneratingItinerary = false
    }

    // MARK: - Load Day Type
    func loadDayType() async {
        guard let token = KeychainManager.shared.getAccessToken() else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: selectedDate)

        guard let url = URL(string: "\(Constants.API.baseURL)/api/v1/planning/day-type?date=\(dateString)") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return }

            self.dayType = try JSONDecoder().decode(DayTypeInfo.self, from: data)

        } catch {
            print("Failed to load day type: \(error)")
        }
    }
}
