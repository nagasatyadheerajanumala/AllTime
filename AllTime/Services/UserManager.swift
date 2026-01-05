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
                // Cache user's first name for personalized notifications
                if let fullName = user.fullName, !fullName.isEmpty {
                    let firstName = fullName.components(separatedBy: " ").first ?? fullName
                    UserDefaults.standard.set(firstName, forKey: "user_first_name")
                    print("👤 UserManager: Cached user first name: \(firstName)")
                }
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
    
    func updateUserProfile(
        fullName: String? = nil,
        email: String? = nil,
        location: String? = nil,
        bio: String? = nil,
        phoneNumber: String? = nil
    ) {
        print("👤 UserManager: Updating user profile...")
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Use the correct APIService method with proper snake_case field names
                let updatedUser = try await apiService.updateUserProfile(
                    fullName: fullName,
                    email: email,
                    preferences: nil,
                    profilePictureUrl: nil,
                    dateOfBirth: nil,
                    gender: nil,
                    location: location,
                    bio: bio,
                    phoneNumber: phoneNumber
                )
                // Update user profile with response
                self.user = updatedUser
                // Update cached first name if fullName changed
                if let fullName = updatedUser.fullName, !fullName.isEmpty {
                    let firstName = fullName.components(separatedBy: " ").first ?? fullName
                    UserDefaults.standard.set(firstName, forKey: "user_first_name")
                }
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
