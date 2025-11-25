//
//  ProfileDetailView.swift
//  AllTime
//
//  Created for displaying user profile details
//

import SwiftUI
import PhotosUI

// MARK: - Shared Components

/// Profile Picture Picker Component - Shared between ProfileSetupView and ProfileDetailView
struct ProfilePicturePicker: View {
    @Binding var image: UIImage?
    @Binding var showImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture Preview
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // Action Button
            Button(action: {
                showImagePicker = true
            }) {
                Text(image == nil ? "Add Photo" : "Change Photo")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $image)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            guard let result = results.first else { return }
            
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            self?.parent.image = image
                        } else if let error = error {
                            print("❌ ImagePicker: Failed to load image: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
}

struct ProfileDetailView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var settingsViewModel: SettingsViewModel
    
    @StateObject private var locationManager = LocationManager.shared
    
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var location: String = ""
    @State private var profilePicture: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    private let apiService = APIService()
    
    var body: some View {
        Form {
            Section {
                HStack {
                    // Profile Picture - Prioritize local image, then URL, then placeholder
                    if let profilePicture = profilePicture {
                        // Show locally selected/loaded image
                        Image(uiImage: profilePicture)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemGray5), lineWidth: 0.5)
                            )
                    } else if let profilePictureUrl = authService.currentUser?.profilePictureUrl ?? settingsViewModel.user?.profilePictureUrl,
                              !profilePictureUrl.isEmpty,
                              let url = URL(string: profilePictureUrl) {
                        // Show image from URL
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(width: 80, height: 80)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color(.systemGray5), lineWidth: 0.5)
                                    )
                            case .failure:
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                    .frame(width: 80, height: 80)
                            @unknown default:
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue)
                                    .frame(width: 80, height: 80)
                            }
                        }
                    } else {
                        // Show placeholder
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .frame(width: 80, height: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Show name - prioritize local state, fallback to user object
                        Text(displayName)
                            .font(.headline)
                        
                        // Show email - prioritize local state, fallback to user object
                        Text(displayEmail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            } header: {
                Text("PROFILE INFORMATION")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            Section {
                ProfilePicturePicker(image: $profilePicture, showImagePicker: $showImagePicker)
            } header: {
                Text("PROFILE PICTURE")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            Section {
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
            } header: {
                Text("PERSONAL INFORMATION")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            Section {
                Button(action: {
                    Task {
                        await saveProfile()
                    }
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(fullName.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            if let success = successMessage {
                Section {
                    Text(success)
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
            
            Section {
                HStack {
                    Text("User ID")
                    Spacer()
                    Text("\(authService.currentUser?.id ?? 0)")
                        .foregroundColor(.secondary)
                }
                
                if let createdAtString = authService.currentUser?.createdAt, !createdAtString.isEmpty {
                    HStack {
                        Text("Member Since")
                        Spacer()
                        Text(formatDateString(createdAtString))
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("Profile Completed")
                    Spacer()
                    Text(authService.currentUser?.profileCompleted == true ? "Yes" : "No")
                        .foregroundColor(authService.currentUser?.profileCompleted == true ? .green : .orange)
                }
            } header: {
                Text("ACCOUNT INFORMATION")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaPadding(.bottom, 110) // Reserve space for tab bar
        .onAppear {
            loadProfileData()
        }
        .onChange(of: authService.currentUser?.id) { oldValue, newValue in
            // Reload when user data changes
            if newValue != nil {
                loadProfileData()
            }
        }
        .onChange(of: authService.currentUser?.profilePictureUrl) { oldValue, newValue in
            // Reload profile picture when URL changes
            if let newUrl = newValue, !newUrl.isEmpty, let url = URL(string: newUrl) {
                loadImageFromURL(url)
            }
        }
        .onChange(of: locationManager.locationString) { oldValue, newValue in
            if let locationString = newValue, location.isEmpty {
                location = locationString
            }
        }
    }
    
    // Computed properties for display - prioritize local state, fallback to user object
    private var displayName: String {
        if !fullName.isEmpty {
            return fullName
        }
        return authService.currentUser?.fullName ?? settingsViewModel.user?.fullName ?? "No name set"
    }
    
    private var displayEmail: String {
        if !email.isEmpty {
            return email
        }
        return authService.currentUser?.email ?? settingsViewModel.user?.email ?? "No email set"
    }
    
    private func loadProfileData() {
        // Prioritize authService.currentUser, fallback to settingsViewModel.user
        let user = authService.currentUser ?? settingsViewModel.user
        
        guard let user = user else {
            print("⚠️ ProfileDetailView: No user data available")
            return
        }
        
        // Update local state with user data
        fullName = user.fullName ?? ""
        email = user.email ?? ""
        location = user.location ?? ""
        
        // Load profile picture from URL if available
        if let profilePictureUrl = user.profilePictureUrl,
           !profilePictureUrl.isEmpty,
           let url = URL(string: profilePictureUrl) {
            print("📸 ProfileDetailView: Loading profile picture from URL: \(profilePictureUrl)")
            loadImageFromURL(url)
        } else {
            // Clear profile picture if no URL
            profilePicture = nil
        }
        
        print("✅ ProfileDetailView: Profile data loaded - Name: \(fullName), Email: \(email), Location: \(location)")
    }
    
    private func loadImageFromURL(_ url: URL) {
        Task {
            do {
                print("📸 ProfileDetailView: Fetching image from URL: \(url)")
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📸 ProfileDetailView: Image response status: \(httpResponse.statusCode)")
                }
                
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        profilePicture = image
                        print("✅ ProfileDetailView: Profile picture loaded successfully")
                    }
                } else {
                    print("❌ ProfileDetailView: Failed to create UIImage from data")
                }
            } catch {
                print("❌ ProfileDetailView: Failed to load profile picture: \(error.localizedDescription)")
                await MainActor.run {
                    profilePicture = nil
                }
            }
        }
    }
    
    private func saveProfile() async {
        isSaving = true
        errorMessage = nil
        successMessage = nil
        
        // Validate full name
        let trimmedName = fullName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            await MainActor.run {
                errorMessage = "Full name is required"
                isSaving = false
            }
            return
        }
        
        // Validate email if provided
        if !email.isEmpty {
            let emailPredicate = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}")
            if !emailPredicate.evaluate(with: email) {
                await MainActor.run {
                    errorMessage = "Please enter a valid email address"
                    isSaving = false
                }
                return
            }
        }
        
        do {
            // First, update profile picture separately if selected
            // Use POST /api/user/profile/picture endpoint (per API documentation)
            var updatedUser: User? = nil
            
            if let image = profilePicture {
                // For MVP, we'll need to upload to a storage service first
                // For now, we'll skip profile picture upload or use a placeholder
                // TODO: Implement image upload to storage service (Firebase Storage, AWS S3, etc.)
                print("📸 ProfileDetailView: Profile picture selected but upload not implemented yet")
                print("📸 ProfileDetailView: Once upload is implemented, use POST /api/user/profile/picture endpoint")
                // Example implementation:
                // let imageUrl = try await uploadImageToStorage(image)
                // updatedUser = try await apiService.updateProfilePicture(url: imageUrl)
            }
            
            // Update other profile fields using PUT /api/user/update
            // Note: Don't include profile_picture_url here - use separate endpoint
            let userAfterUpdate = try await apiService.updateUserProfile(
                fullName: trimmedName,
                email: email.isEmpty ? nil : email,
                preferences: nil,
                profilePictureUrl: nil, // Don't update picture here - use separate endpoint
                dateOfBirth: nil,
                gender: nil,
                location: location.isEmpty ? nil : location,
                bio: nil,
                phoneNumber: nil
            )
            
            // Use the user from profile picture update if available, otherwise use general update
            let finalUser = updatedUser ?? userAfterUpdate
            
            // Preserve createdAt from current user if backend didn't return it
            let userWithCreatedAt = User(
                id: finalUser.id,
                email: finalUser.email,
                fullName: finalUser.fullName,
                createdAt: finalUser.createdAt ?? authService.currentUser?.createdAt,
                profilePictureUrl: finalUser.profilePictureUrl ?? updatedUser?.profilePictureUrl,
                profileCompleted: finalUser.profileCompleted,
                dateOfBirth: finalUser.dateOfBirth,
                gender: finalUser.gender,
                location: finalUser.location,
                bio: finalUser.bio,
                phoneNumber: finalUser.phoneNumber
            )
            
            // Update auth service with new user data
            await MainActor.run {
                authService.currentUser = userWithCreatedAt
                settingsViewModel.user = userWithCreatedAt
                successMessage = "Profile updated successfully!"
                errorMessage = nil
                
                // Reload local state with updated data
                loadProfileData()
            }
            
            // Clear success message after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                successMessage = nil
            }
        } catch {
            await MainActor.run {
                // Provide more user-friendly error messages
                if let decodingError = error as? DecodingError {
                    errorMessage = "Failed to update profile. Please try again."
                    print("❌ ProfileDetailView: Decoding error: \(decodingError)")
                } else if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost:
                        errorMessage = "No internet connection. Please check your network and try again."
                    case .timedOut:
                        errorMessage = "Request timed out. Please try again."
                    default:
                        errorMessage = "Failed to update profile. Please try again."
                    }
                } else {
                    errorMessage = "Failed to update profile: \(error.localizedDescription)"
                }
                print("❌ ProfileDetailView: Error updating profile: \(error)")
                isSaving = false
            }
            return
        }
        
        await MainActor.run {
            isSaving = false
        }
    }
    
    private func formatDateString(_ dateString: String) -> String {
        // Parse ISO 8601 date string
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        } else {
            // Try without fractional seconds
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let date = isoFormatter.date(from: dateString) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                return formatter.string(from: date)
            }
        }
        
        // If parsing fails, return the original string
        return dateString
    }
}

#Preview {
    NavigationView {
        ProfileDetailView()
            .environmentObject(AuthenticationService())
            .environmentObject(SettingsViewModel())
    }
}

