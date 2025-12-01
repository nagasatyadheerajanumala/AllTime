//
//  ProfileSetupView.swift
//  AllTime
//
//  Created for profile setup flow
//

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var location: String = ""
    @State private var profilePicture: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showImagePicker = false
    
    @EnvironmentObject var authService: AuthenticationService
    @StateObject private var locationManager = LocationManager.shared
    private let apiService = APIService()
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Welcome to Chrona!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 40)
                    
                    Text("Complete your profile to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 24)
                
                // Form
                Form {
                    Section(header: Text("Profile Picture")) {
                        ProfilePicturePicker(image: $profilePicture, showImagePicker: $showImagePicker)
                    }
                    
                    Section(header: Text("Personal Information")) {
                        TextField("Full Name", text: $fullName)
                            .textContentType(.name)
                            .autocapitalization(.words)
                        
                        TextField("Email", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                        
                        HStack {
                            TextField("Location", text: $location)
                                .textContentType(.location)
                                .autocapitalization(.words)
                            
                            if locationManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Button(action: {
                                    locationManager.getCurrentLocation()
                                }) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    
                    if let error = errorMessage {
                        Section {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                // Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await saveProfile()
                        }
                    }) {
                        Text("Complete Profile")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(fullName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    
                    Button(action: {
                        // Skip - go to main app
                        Task {
                            await skipProfileSetup()
                        }
                    }) {
                        Text("Skip for Now")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.blue)
                    }
                    .disabled(isLoading)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                // Pre-fill email from current user if available
                if email.isEmpty, let userEmail = authService.currentUser?.email {
                    email = userEmail
                }
                // Pre-fill full name if available
                if fullName.isEmpty, let userName = authService.currentUser?.fullName {
                    fullName = userName
                }
                // Pre-fill location if available
                if location.isEmpty, let userLocation = authService.currentUser?.location {
                    location = userLocation
                }
            }
            .onChange(of: locationManager.locationString) { oldValue, newValue in
                if let locationString = newValue, location.isEmpty {
                    location = locationString
                }
            }
        }
    }
    
    private func saveProfile() async {
        isLoading = true
        errorMessage = nil
        
        // Validate full name
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Full name is required"
            isLoading = false
            return
        }
        
        // Validate email if provided
        if !email.isEmpty {
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
            if !emailPredicate.evaluate(with: email) {
                errorMessage = "Please enter a valid email address"
                isLoading = false
                return
            }
        }
        
        // Upload profile picture if selected
        var profilePictureUrl: String? = nil
        if let image = profilePicture {
            // For MVP, we'll need to upload to a storage service first
            // For now, we'll skip profile picture upload or use a placeholder
            // TODO: Implement image upload to storage service (Firebase Storage, AWS S3, etc.)
            print("📸 ProfileSetupView: Profile picture selected but upload not implemented yet")
            // profilePictureUrl = try await uploadProfilePicture(image)
        }
        
        do {
            print("📝 ProfileSetupView: Starting profile setup...")
            print("📝 ProfileSetupView: Full Name: \(trimmedName)")
            print("📝 ProfileSetupView: Email: \(email.isEmpty ? "nil" : email)")
            
            let updatedUser = try await apiService.setupProfile(
                fullName: trimmedName,
                email: email.isEmpty ? nil : email,
                profilePictureUrl: profilePictureUrl,
                dateOfBirth: nil,
                gender: nil,
                location: location.isEmpty ? nil : location,
                bio: nil,
                phoneNumber: nil
            )
            
            print("✅ ProfileSetupView: Profile setup successful!")
            print("✅ ProfileSetupView: Updated user ID: \(updatedUser.id)")
            print("✅ ProfileSetupView: Profile completed: \(updatedUser.profileCompleted ?? false)")
            
            // Update auth service with new user data first
            // This ensures the user object is updated with profile_completed: true
            await MainActor.run {
                authService.currentUser = updatedUser
            }
            
            // Small delay to ensure UI updates before navigation
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Then dismiss the setup view to navigate to main app
            await MainActor.run {
                onDismiss?()
            }
        } catch {
            print("❌ ProfileSetupView: Profile setup failed!")
            print("❌ ProfileSetupView: Error: \(error)")
            if let urlError = error as? URLError {
                print("❌ ProfileSetupView: URL Error code: \(urlError.code.rawValue)")
                print("❌ ProfileSetupView: URL Error description: \(urlError.localizedDescription)")
            }
            if let decodingError = error as? DecodingError {
                print("❌ ProfileSetupView: Decoding error: \(decodingError)")
            }
            
            await MainActor.run {
                // Show more detailed error message
                if let apiError = error as? NSError {
                    errorMessage = "Failed to save profile: \(apiError.localizedDescription)"
                } else {
                    errorMessage = "Failed to save profile: \(error.localizedDescription)"
                }
            }
        }
        
        isLoading = false
    }
    
    private func skipProfileSetup() async {
        // User skipped profile setup - just refresh profile and go to main app
        // The profile_completed flag will remain false, but user can add details later
        // We'll update the user object to indicate they've seen the setup screen
        // but allow them to proceed to main app
        isLoading = true
        
        // Refresh user profile to ensure we have latest data
        do {
            let profile = try await apiService.fetchUserProfile()
            await MainActor.run {
                // Update user but keep profile_completed as false
                // ContentView will check this and show PremiumTabView anyway
                // since we're authenticated
                authService.currentUser = profile
            }
        } catch {
            // If refresh fails, that's okay - user is still authenticated
            // Just proceed to main app
            print("⚠️ ProfileSetupView: Failed to refresh profile after skip: \(error)")
        }
        
        isLoading = false
        
        // Dismiss the profile setup screen
        await MainActor.run {
            onDismiss?()
        }
    }
}

// ProfilePicturePicker is now defined in ProfileDetailView.swift as a shared component

#Preview {
    ProfileSetupView()
        .environmentObject(AuthenticationService())
}

