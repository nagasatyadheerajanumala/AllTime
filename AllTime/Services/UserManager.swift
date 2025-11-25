import Foundation
import Combine

@MainActor
class UserManager: ObservableObject {
    @Published var user: User?
    @Published var preferences: String = "{}"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadUserProfile()
    }
    
    // MARK: - User Profile
    
    func loadUserProfile() {
        print("👤 UserManager: Loading user profile...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let user = try await apiService.fetchUserProfile()
                self.user = user
                isLoading = false
                print("👤 UserManager: User profile loaded successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("👤 UserManager: Failed to load user profile: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchUserProfile() {
        loadUserProfile()
    }
    
    func updateUserProfile(fullName: String, email: String?) {
        print("👤 UserManager: Updating user profile...")
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let updatedUser = try await apiService.updateUserProfile(fullName: fullName, email: email)
                // Update user profile with response
                self.user = updatedUser
                isLoading = false
                print("👤 UserManager: User profile updated successfully")
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
                print("👤 UserManager: Failed to update user profile: \(error.localizedDescription)")
            }
        }
    }
    
    func fetchUserPreferences() {
        print("👤 UserManager: Fetching user preferences...")
        
        Task {
            do {
                let prefs = try await apiService.fetchUserPreferences()
                preferences = prefs
                print("👤 UserManager: User preferences loaded successfully")
            } catch {
                print("👤 UserManager: Failed to load user preferences: \(error.localizedDescription)")
            }
        }
    }
}
