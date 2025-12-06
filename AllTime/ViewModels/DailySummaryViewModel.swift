import Foundation
import SwiftUI
import Combine

@MainActor
class DailySummaryViewModel: ObservableObject {
    @Published var summary: DailySummaryResponse?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = Constants.API.baseURL
    private var loadTask: Task<Void, Never>?
    
    func loadSummary() async {
        // Cancel any existing load
        loadTask?.cancel()
        
        loadTask = Task {
            await performLoad()
        }
        
        await loadTask?.value
    }
    
    private func performLoad() async {
        guard !isLoading else {
            print("⚠️ DailySummaryViewModel: Already loading, skipping...")
            return
        }
        
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        print("📊 DailySummaryViewModel: Loading daily summary...")
        
        guard let token = KeychainManager.shared.getAccessToken() else {
            print("❌ DailySummaryViewModel: No access token")
            errorMessage = "Not authenticated"
            return
        }
        
        // Add timestamp to bust any caches
        let timestamp = Int(Date().timeIntervalSince1970)
        let urlString = "\(baseURL)/api/v1/daily-summary?t=\(timestamp)"
        guard let url = URL(string: urlString) else {
            print("❌ DailySummaryViewModel: Invalid URL")
            errorMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData  // Force fresh data
        
        print("📤 DailySummaryViewModel: Requesting from: \(urlString)")
        print("📤 DailySummaryViewModel: Cache policy: reloadIgnoringCache (FORCE FRESH)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if task was cancelled
            if Task.isCancelled {
                print("⚠️ DailySummaryViewModel: Request was cancelled")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ DailySummaryViewModel: Invalid response")
                errorMessage = "Invalid response"
                return
            }
            
            print("📥 DailySummaryViewModel: Response status: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ DailySummaryViewModel: Error response: \(responseString)")
                }
                errorMessage = "Server error: \(httpResponse.statusCode)"
                return
            }
            
            // Log raw JSON for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 DailySummaryViewModel: Raw JSON: \(responseString)")
            }
            
            let decoder = JSONDecoder()
            // Don't use convertFromSnakeCase - we have explicit CodingKeys
            
            let summaryResponse = try decoder.decode(DailySummaryResponse.self, from: data)
            self.summary = summaryResponse
            
            print("✅ DailySummaryViewModel: Successfully loaded summary")
            print("   - Day summary: \(summaryResponse.daySummary.count) items")
            print("   - Health summary: \(summaryResponse.healthSummary.count) items")
            print("   - Alerts: \(summaryResponse.alerts.count) items")
            print("   - Health suggestions: \(summaryResponse.healthBasedSuggestions.count) items")
            
            if let location = summaryResponse.locationRecommendations {
                print("   - Location: \(location.userCity ?? "unknown"), \(location.userCountry ?? "unknown")")
                if let lunch = location.lunchRecommendation, let spots = lunch.nearbySpots {
                    print("   - Lunch spots: \(spots.count)")
                }
                if let walks = location.walkRoutes {
                    print("   - Walk routes: \(walks.count)")
                }
            }
            
        } catch let decodingError as DecodingError {
            print("❌ DailySummaryViewModel: Decoding error: \(decodingError)")
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("   Missing key: \(key.stringValue)")
                print("   Context: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("   Type mismatch: \(type)")
                print("   Context: \(context.debugDescription)")
            case .valueNotFound(let type, let context):
                print("   Value not found: \(type)")
                print("   Context: \(context.debugDescription)")
            case .dataCorrupted(let context):
                print("   Data corrupted: \(context.debugDescription)")
            @unknown default:
                print("   Unknown decoding error")
            }
            errorMessage = "Failed to parse summary"
        } catch {
            print("❌ DailySummaryViewModel: Network error: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    func refreshSummary() async {
        await loadSummary()
    }
}
