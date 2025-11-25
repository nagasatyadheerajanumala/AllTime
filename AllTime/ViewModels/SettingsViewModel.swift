import Foundation
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var user: User?
    @Published var providers: [Provider] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isLinkingProvider = false
    
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    var connectedProvidersCount: Int? {
        providers.isEmpty ? nil : providers.count
    }
    
    init() {
        Task {
            await loadUserProfile()
            await loadProviders()
        }
    }
    
    func loadUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await apiService.fetchUserProfile()
            // Note: Providers are now managed separately, not part of User model
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func linkProvider(_ provider: String, authCode: String) async {
        isLinkingProvider = true
        errorMessage = nil
        
        do {
            let newProvider = try await apiService.linkProvider(provider: provider, authCode: authCode)
            providers.append(newProvider)
            isLinkingProvider = false
        } catch {
            errorMessage = error.localizedDescription
            isLinkingProvider = false
        }
    }
    
    func unlinkProvider(_ providerId: Int) async {
        // This would require a new API endpoint
        // For now, we'll just remove from local state
        providers.removeAll { $0.id == providerId }
    }
    
    func loadProviders() async {
        do {
            let response = try await apiService.getConnectedProviders()
            providers = response.providers
        } catch {
            print("❌ SettingsViewModel: Failed to load providers: \(error)")
            // Don't show error to user, just log it
        }
    }
    
    func refreshProviders() async {
        await loadUserProfile()
        await loadProviders()
    }
}
