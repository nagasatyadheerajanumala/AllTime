import Foundation
import Combine
import EventKit

class APIService: ObservableObject {
    private let baseURL = Constants.API.baseURL
    private let session = URLSession.shared
    
    private var accessToken: String? {
        KeychainManager.shared.getAccessToken()
    }
    
    private var tokenType: String? {
        UserDefaults.standard.string(forKey: "token_type")
    }
    
    // Track if we're currently refreshing to avoid infinite loops
    private var isRefreshingToken = false
    private let refreshLock = NSLock()
    
    // MARK: - Authentication
    func signInWithApple(identityToken: String, authorizationCode: String?, userIdentifier: String, email: String?, fullName: PersonNameComponents?) async throws -> AuthResponse {
        let url = URL(string: "\(baseURL)/auth/apple")!
        print("🌐 APIService: ===== APPLE SIGN-IN REQUEST =====")
        print("🌐 APIService: Request URL: \(url)")
        print("🌐 APIService: Base URL: \(baseURL)")
        print("🌐 APIService: User ID: \(userIdentifier)")
        print("🌐 APIService: Email: \(email ?? "nil")")
        print("🌐 APIService: Has Full Name: \(fullName != nil)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        // Validate identityToken is not empty
        guard !identityToken.isEmpty else {
            print("❌ APIService: identityToken is empty!")
            throw NSError(domain: "AllTime", code: 1, userInfo: [NSLocalizedDescriptionKey: "identityToken cannot be empty"])
        }
        
        // Manually construct JSON to ensure proper encoding
        // Backend API docs show camelCase 'identityToken' in examples
        var jsonDict: [String: Any] = [
            "identityToken": identityToken  // Using camelCase as per API documentation examples
        ]
        
        // Add email if provided (only include in JSON if not nil/empty)
        if let email = email, !email.isEmpty {
            jsonDict["email"] = email
            print("🌐 APIService: Email included: \(email)")
        } else {
            print("🌐 APIService: Email not provided (will be omitted from JSON)")
            // Don't include email key if nil/empty - backend handles this
        }
        
        print("🌐 APIService: JSON Dictionary keys: \(jsonDict.keys.joined(separator: ", "))")
        print("🌐 APIService: identityToken length: \(identityToken.count) characters")
        print("🌐 APIService: identityToken prefix: \(identityToken.prefix(50))...")
        print("🌐 APIService: Sending with field name 'identityToken' (camelCase)")
        print("🌐 APIService: Email provided: \(email != nil ? "Yes (\(email!))" : "No (nil)")")
        
        // Encode to JSON (compact format for backend compatibility)
        do {
            request.httpBody = try JSONSerialization.data(
                withJSONObject: jsonDict,
                options: []
            )
        } catch {
            print("❌ APIService: Failed to serialize JSON: \(error)")
            throw error
        }
        
        // Verify the encoded body contains the token
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("🌐 APIService: Request body (first 200 chars): \(String(bodyString.prefix(200)))")
            print("🌐 APIService: Request body (full): \(bodyString)")
            
            // Verify identityToken is in the JSON
            if !bodyString.contains("identityToken") {
                print("⚠️ APIService: WARNING - 'identityToken' key not found in JSON!")
                print("⚠️ APIService: JSON keys found: \(jsonDict.keys.joined(separator: ", "))")
            } else {
                print("✅ APIService: 'identityToken' key confirmed in JSON")
            }
            
            // Verify token value is present
            let tokenPrefix = identityToken.prefix(50)
            if !bodyString.contains(tokenPrefix) {
                print("⚠️ APIService: WARNING - identityToken value might not be in request body!")
                print("⚠️ APIService: Looking for: \(tokenPrefix)...")
            } else {
                print("✅ APIService: identityToken value confirmed in request body")
            }
        } else {
            print("❌ APIService: Failed to create request body string!")
            throw NSError(domain: "AllTime", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request body"])
        }
        
        print("🌐 APIService: Request body prepared with user: \(userIdentifier)")
        print("🌐 APIService: Request headers: \(request.allHTTPHeaderFields ?? [:])")

        print("🌐 APIService: Sending request...")
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🌐 APIService: ===== APPLE SIGN-IN RESPONSE =====")
        print("🌐 APIService: HTTP Status Code: \(statusCode)")
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 APIService: Response Headers: \(httpResponse.allHeaderFields)")
        } else {
            print("🌐 APIService: Response Headers: Not available (not HTTP response)")
        }

        // Always log the response body for debugging
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("🌐 APIService: Response Body: \(responseString)")

        if statusCode != 200 {
            print("❌ APIService: ===== ERROR RESPONSE =====")
            print("❌ APIService: Error Status: \(statusCode)")
            print("❌ APIService: Error Body: \(responseString)")
        } else {
            print("✅ APIService: Success Response Received")
        }
        
        try await validateResponse(response, data: data)
        
        do {
            // Decode AuthResponse
            // Note: AuthResponse and User both have explicit CodingKeys, so we don't need keyDecodingStrategy
            let decoder = JSONDecoder()
            let authResponse = try decoder.decode(AuthResponse.self, from: data)
            print("🌐 APIService: Response decoded successfully, token: \(authResponse.accessToken.prefix(20))...")
            return authResponse
        } catch {
            print("🌐 APIService: Failed to decode AuthResponse: \(error)")
            print("🌐 APIService: Raw response data: \(responseString)")
            
            // Log detailed decoding error
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ APIService: Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("❌ APIService: Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    print("❌ APIService: Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("❌ APIService: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("❌ APIService: Unknown decoding error")
                }
            }
            
            throw error
        }
    }
    
    func logout() async throws {
        let url = URL(string: "\(baseURL)/auth/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    func refreshToken(refreshToken: String) async throws -> RefreshTokenResponse {
        let url = URL(string: "\(baseURL)/auth/refresh")!
        print("🔄 APIService: Refreshing token at \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Backend expects camelCase: refreshToken
        let body = ["refreshToken": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🔄 APIService: Refresh response received, status: \(statusCode)")
        
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("🔄 APIService: Refresh response body: \(responseString)")
        
        // Don't use validateResponse here - it will cause infinite loop
        // Handle 401 directly for refresh token endpoint
        if statusCode == 401 {
            print("❌ APIService: Refresh token is also invalid - user must sign in again")
            // Refresh token is invalid - trigger sign out
            NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Refresh token expired. Please sign in again."]
            )
        }
        
        if statusCode != 200 {
            print("🔄 APIService: Refresh failed with status: \(statusCode)")
            throw NSError(
                domain: "AllTime",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Token refresh failed with status: \(statusCode)"]
            )
        }
        
        // Only validate if status is 200
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "AllTime",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from refresh endpoint"]
            )
        }
        
        do {
            // Backend returns snake_case, so convert to camelCase
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let refreshResponse = try decoder.decode(RefreshTokenResponse.self, from: data)
            print("🔄 APIService: Token refresh successful")
            return refreshResponse
        } catch {
            print("🔄 APIService: Failed to decode RefreshTokenResponse: \(error)")
            print("🔄 APIService: Raw response data: \(responseString)")
            throw error
        }
    }
    
    func linkProvider(provider: String, authCode: String) async throws -> Provider {
        let url = URL(string: "\(baseURL)/auth/\(provider)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let body = ProviderLinkRequest(provider: provider, authCode: authCode)
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        return try JSONDecoder().decode(Provider.self, from: data)
    }
    
    // MARK: - User Profile
    func fetchUserProfile() async throws -> User {
        // Backend endpoint: GET /api/user/me (per frontend developer guide)
        let url = URL(string: "\(baseURL)/api/user/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(User.self, from: data)
    }
    
    func setupProfile(
        fullName: String,
        email: String?,
        profilePictureUrl: String?,
        dateOfBirth: String? = nil,
        gender: String? = nil,
        location: String? = nil,
        bio: String? = nil,
        phoneNumber: String? = nil
    ) async throws -> User {
        let url = URL(string: "\(baseURL)/api/user/profile/setup")!
        print("🌐 APIService: ===== SETUP PROFILE REQUEST =====")
        print("🌐 APIService: URL: \(url)")
        print("🌐 APIService: Full Name: \(fullName)")
        print("🌐 APIService: Email: \(email ?? "nil")")
        print("🌐 APIService: Profile Picture URL: \(profilePictureUrl ?? "nil")")
        print("🌐 APIService: Access Token: \(accessToken != nil ? "Present" : "Missing")")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let requestBody = SetupProfileRequest(
            fullName: fullName,
            email: email,
            profilePictureUrl: profilePictureUrl,
            dateOfBirth: dateOfBirth,
            gender: gender,
            location: location,
            bio: bio,
            phoneNumber: phoneNumber
        )
        
        do {
            request.httpBody = try encoder.encode(requestBody)
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("🌐 APIService: Request Body: \(bodyString)")
            }
        } catch {
            print("❌ APIService: Failed to encode request body: \(error)")
            throw error
        }
        
        print("🌐 APIService: Sending POST request...")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 APIService: Response status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("🌐 APIService: Response body: \(responseString)")
                }
            }
            
            try await validateResponse(response, data: data)
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let user = try decoder.decode(User.self, from: data)
            
            print("✅ APIService: Profile setup successful!")
            print("✅ APIService: User ID: \(user.id)")
            print("✅ APIService: Profile completed: \(user.profileCompleted ?? false)")
            
            return user
        } catch {
            print("❌ APIService: Profile setup failed!")
            print("❌ APIService: Error: \(error)")
            if let urlError = error as? URLError {
                print("❌ APIService: URL Error: \(urlError.localizedDescription)")
            }
            if let decodingError = error as? DecodingError {
                print("❌ APIService: Decoding Error: \(decodingError)")
            }
            throw error
        }
    }
    
    func updateUserProfile(
        fullName: String? = nil,
        email: String? = nil,
        preferences: String? = nil,
        profilePictureUrl: String? = nil,
        dateOfBirth: String? = nil,
        gender: String? = nil,
        location: String? = nil,
        bio: String? = nil,
        phoneNumber: String? = nil
    ) async throws -> User {
        // Backend endpoint: PUT /api/user/update (per API documentation)
        let url = URL(string: "\(baseURL)/api/user/update")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        var body: [String: Any] = [:]
        if let fullName = fullName {
            body["full_name"] = fullName
        }
        if let email = email {
            body["email"] = email
        }
        if let preferences = preferences {
            body["preferences"] = preferences
        }
        if let profilePictureUrl = profilePictureUrl {
            body["profile_picture_url"] = profilePictureUrl
        }
        if let dateOfBirth = dateOfBirth {
            body["date_of_birth"] = dateOfBirth
        }
        if let gender = gender {
            body["gender"] = gender
        }
        if let location = location {
            body["location"] = location
        }
        if let bio = bio {
            body["bio"] = bio
        }
        if let phoneNumber = phoneNumber {
            body["phone_number"] = phoneNumber
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("🌐 APIService: Update profile request body: \(bodyString)")
        }
        
        print("🌐 APIService: Sending PUT request to \(url)")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 APIService: Update profile response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🌐 APIService: Update profile response body: \(responseString)")
            }
        }
        
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let user = try decoder.decode(User.self, from: data)
            print("✅ APIService: Profile updated successfully")
            return user
        } catch {
            print("❌ APIService: Failed to decode updated user profile")
            print("❌ APIService: Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ APIService: Missing key: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("❌ APIService: Type mismatch: \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("❌ APIService: Value not found: \(type) at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("❌ APIService: Data corrupted at path: \(context.codingPath)")
                @unknown default:
                    print("❌ APIService: Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    func updateProfilePicture(url profilePictureUrl: String) async throws -> User {
        // Backend endpoint: POST /api/user/profile/picture (per API documentation)
        let endpointURL = URL(string: "\(baseURL)/api/user/profile/picture")!
        print("🌐 APIService: ===== UPDATE PROFILE PICTURE =====")
        print("🌐 APIService: Endpoint URL: \(endpointURL)")
        print("🌐 APIService: Profile Picture URL: \(profilePictureUrl)")
        
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        let body = ["profile_picture_url": profilePictureUrl]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
            print("🌐 APIService: Request body: \(bodyString)")
        }
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🌐 APIService: Response status: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("🌐 APIService: Response body: \(responseString)")
            }
        }
        
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let user = try decoder.decode(User.self, from: data)
            print("✅ APIService: Profile picture updated successfully")
            return user
        } catch {
            print("❌ APIService: Failed to decode user profile after picture update")
            print("❌ APIService: Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ APIService: Missing key: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("❌ APIService: Type mismatch: \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("❌ APIService: Value not found: \(type) at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("❌ APIService: Data corrupted at path: \(context.codingPath)")
                @unknown default:
                    print("❌ APIService: Unknown decoding error")
                }
            }
            throw error
        }
    }
    
    // MARK: - Events
    func fetchEvents(
        startDate: Date? = nil,
        endDate: Date? = nil,
        days: Int? = nil,
        period: String? = nil,
        page: Int = 1,
        limit: Int? = nil,
        autoSync: Bool = true
    ) async throws -> EventsResponse {
        var components = URLComponents(string: "\(baseURL)/events")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "autoSync", value: String(autoSync))
        ]
        
        if let startDate = startDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            queryItems.append(URLQueryItem(name: "start", value: formatter.string(from: startDate)))
        }
        
        if let endDate = endDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            queryItems.append(URLQueryItem(name: "end", value: formatter.string(from: endDate)))
        }
        
        if let days = days {
            queryItems.append(URLQueryItem(name: "days", value: String(days)))
        }
        
        if let period = period {
            queryItems.append(URLQueryItem(name: "period", value: period))
        }
        
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: String(limit)))
        }
        
        components.queryItems = queryItems
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await session.data(for: request)
            try await validateResponse(response, data: data)
            
            // Note: EventsResponse uses explicit CodingKeys, so keyDecodingStrategy is not needed
            let decoder = JSONDecoder()
            return try decoder.decode(EventsResponse.self, from: data)
        } catch let error as APIError where error.code == "401_REFRESHED" {
            // Token was refreshed, retry the request with new token
            print("🔄 APIService: Retrying fetchEvents after token refresh...")
            var retryRequest = URLRequest(url: components.url!)
            retryRequest.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await session.data(for: retryRequest)
            try await validateResponse(response, data: data)
            
            let decoder = JSONDecoder()
            return try decoder.decode(EventsResponse.self, from: data)
        }
    }
    
    func syncEvents() async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // SyncResponse now includes optional diagnostics
        return try decoder.decode(SyncResponse.self, from: data)
    }
    
    func syncNow() async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/sync/now")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SyncResponse.self, from: data)
    }
    
    func syncMicrosoftCalendar() async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/sync/microsoft")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SyncResponse.self, from: data)
    }
    
    // Legacy method - use fetchEvents() instead for new structured response
    // This method is kept for backward compatibility
    func getAllEvents(days: Int? = nil, page: Int? = nil, limit: Int? = nil, start: Date? = nil, end: Date? = nil) async throws -> EventsResponse {
        // Use the new structured GET /events endpoint
        return try await fetchEvents(
            startDate: start,
            endDate: end,
            days: days,
            page: page ?? 1,
            limit: limit,
            autoSync: false
        )
    }
    
    // MARK: - Daily Summary
    func fetchDailySummary(for date: Date) async throws -> DailySummary {
        // Backend expects date format: yyyy-MM-dd (not ISO8601)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let dateString = formatter.string(from: date)
        
        // Backend endpoint: GET /summaries/{date} (per API documentation)
        let url = URL(string: "\(baseURL)/summaries/\(dateString)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        return try JSONDecoder().decode(DailySummary.self, from: data)
    }
    
    func fetchTodaySummary() async throws -> DailySummary {
        let url = URL(string: "\(baseURL)/api/summary/today")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        return try JSONDecoder().decode(DailySummary.self, from: data)
    }
    
    func forceGenerateSummary() async throws -> DailySummary {
        let url = URL(string: "\(baseURL)/api/summary/send-now")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        return try JSONDecoder().decode(DailySummary.self, from: data)
    }
    
    func fetchSummaryPreferences() async throws -> SummaryPreferences {
        let url = URL(string: "\(baseURL)/api/summary/preferences")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        return try JSONDecoder().decode(SummaryPreferences.self, from: data)
    }
    
    func updateSummaryPreferences(_ preferences: SummaryPreferences) async throws {
        let url = URL(string: "\(baseURL)/api/summary/preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONEncoder().encode(preferences)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    // MARK: - User Management
    // Note: Use the updateUserProfile method with multiple optional parameters above (line ~348)
    // It uses the correct endpoint /api/user/update with snake_case field names
    
    func fetchUserPreferences() async throws -> String {
        let url = URL(string: "\(baseURL)/api/user/preferences")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    
    // MARK: - Calendar Sync
    func syncEvents(events: [EKEvent]) async throws {
        let url = URL(string: "\(baseURL)/eventkit/import")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let eventData = events.map { event in
            [
                "title": event.title ?? "",
                "start_time": ISO8601DateFormatter().string(from: event.startDate),
                "end_time": ISO8601DateFormatter().string(from: event.endDate),
                "location": event.location ?? "",
                "notes": event.notes ?? "",
                "all_day": event.isAllDay,
                "calendar_title": event.calendar.title
            ]
        }
        
        let body = ["events": eventData]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    // MARK: - OAuth Flows
    func getGoogleOAuthStartURL() async throws -> String {
        let url = URL(string: "\(baseURL)/connections/google/start")!
        print("🔗 APIService: Requesting Google OAuth URL from: \(url)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Constants.API.timeout

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🔗 APIService: Response status: \(statusCode)")

        try await validateResponse(response, data: data)

        // Decode using OAuthStartResponse model
        let decoder = JSONDecoder()
        let oauthResponse = try decoder.decode(OAuthStartResponse.self, from: data)

        print("✅ APIService: OAuth URL received: \(oauthResponse.authorizationUrl)")
        return oauthResponse.authorizationUrl
    }
    
    func completeGoogleOAuth(code: String) async throws {
        let url = URL(string: "\(baseURL)/connections/google/callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let body = ["code": code]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    func getMicrosoftOAuthStartURL() async throws -> String {
        let url = URL(string: "\(baseURL)/connections/microsoft/start")!
        print("🔗 APIService: Requesting Microsoft OAuth URL from: \(url)")

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = Constants.API.timeout

        let (data, response) = try await session.data(for: request)

        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🔗 APIService: Response status: \(statusCode)")

        try await validateResponse(response, data: data)

        // Decode using OAuthStartResponse model
        let decoder = JSONDecoder()
        let oauthResponse = try decoder.decode(OAuthStartResponse.self, from: data)

        print("✅ APIService: OAuth URL received: \(oauthResponse.authorizationUrl)")
        return oauthResponse.authorizationUrl
    }
    
    func completeMicrosoftOAuth(code: String) async throws {
        let url = URL(string: "\(baseURL)/connections/microsoft/callback")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let body = ["code": code]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    // MARK: - Calendar Diagnostics
    
    func getCalendarDiagnostics() async throws -> CalendarDiagnosticsResponse {
        let url = URL(string: "\(baseURL)/calendars/diagnostics")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CalendarDiagnosticsResponse.self, from: data)
    }
    
    // MARK: - Sync Status
    
    func getSyncStatus() async throws -> SyncStatusResponse {
        let url = URL(string: "\(baseURL)/sync/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SyncStatusResponse.self, from: data)
    }
    
    // MARK: - Summary Preferences
    
    func updateSummaryPreferences(timePreference: String, includeWeather: Bool, includeTraffic: Bool) async throws -> SummaryPreferencesResponse {
        let url = URL(string: "\(baseURL)/summaries/preferences")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "time_preference": timePreference,
            "include_weather": includeWeather,
            "include_traffic": includeTraffic
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SummaryPreferencesResponse.self, from: data)
    }
    
    // MARK: - Push Notifications
    func registerDeviceToken(_ deviceToken: String) async throws {
        // Backend endpoint: POST /push/register (per API documentation)
        let url = URL(string: "\(baseURL)/push/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        // Backend expects camelCase: deviceToken
        let body = ["deviceToken": deviceToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    func sendTestNotification() async throws {
        // Backend endpoint: POST /push/test (per API documentation)
        let url = URL(string: "\(baseURL)/push/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    func sendDailySummaryNotification() async throws {
        // Backend endpoint: POST /push/test (per API documentation)
        let url = URL(string: "\(baseURL)/push/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    func sendCalendarSyncNotification() async throws {
        let url = URL(string: "\(baseURL)/api/push/calendar-sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
    }
    
    func getPushNotificationStatus() async throws -> PushNotificationStatus {
        let url = URL(string: "\(baseURL)/api/push/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PushNotificationStatus.self, from: data)
    }
    
    func getGoogleConnectionStatus() async throws -> ConnectionStatus {
        let url = URL(string: "\(baseURL)/connections/google/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ConnectionStatus.self, from: data)
    }
    
    func getMicrosoftConnectionStatus() async throws -> ConnectionStatus {
        let url = URL(string: "\(baseURL)/connections/microsoft/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ConnectionStatus.self, from: data)
    }
    
    func fetchSummaryHistory(startDate: String, endDate: String) async throws -> SummaryHistoryResponse {
        var components = URLComponents(string: "\(baseURL)/api/summary/history")!
        components.queryItems = [
            URLQueryItem(name: "start", value: startDate),
            URLQueryItem(name: "end", value: endDate)
        ]
        
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SummaryHistoryResponse.self, from: data)
    }
    
    // MARK: - Health Check
    func healthCheck() async throws -> Bool {
        let url = URL(string: "\(baseURL)/health")!
        print("🌐 APIService: Health check to \(url)")
        
        let (data, response) = try await session.data(from: url)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🌐 APIService: Health check response - Status: \(statusCode)")
        
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("🌐 APIService: Health check response body: \(responseString)")
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }
    
    // MARK: - Backend Connection Test
    func testBackendConnection() async {
        print("🌐 APIService: ===== BACKEND CONNECTION TEST =====")
        print("🌐 APIService: Testing backend connection...")
        print("🌐 APIService: Base URL: \(baseURL)")
        print("🌐 APIService: Health Check URL: \(baseURL)/health")
        
        do {
            let isHealthy = try await healthCheck()
            print("🌐 APIService: ===== HEALTH CHECK RESULT =====")
            print("🌐 APIService: Backend health check result: \(isHealthy)")
            if isHealthy {
                print("✅ APIService: Backend is healthy and reachable")
            } else {
                print("❌ APIService: Backend health check failed")
            }
        } catch {
            print("❌ APIService: ===== CONNECTION TEST FAILED =====")
            print("❌ APIService: Backend connection test failed: \(error)")
            print("❌ APIService: Error details: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Calendar Management
    func getConnectedCalendars() async throws -> CalendarListResponse {
        let url = URL(string: "\(baseURL)/calendars")!
        print("🌐 APIService: Fetching connected calendars from \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Constants.API.timeout
        
        // Add authorization header
        if let token = accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)
        
        // Log response for debugging account names
        if let responseString = String(data: data, encoding: .utf8) {
            print("🌐 APIService: Calendar response: \(responseString)")
        }
        
        // Use standard decoder - ConnectedCalendar has explicit CodingKeys for snake_case conversion
        let calendarResponse = try JSONDecoder().decode(CalendarListResponse.self, from: data)
        
        // Log calendar details for debugging
        for calendar in calendarResponse.calendars {
            print("📅 APIService: Calendar - Provider: \(calendar.provider), External User ID: \(calendar.externalUserId), Display Name: \(calendar.displayName)")
        }
        
        print("✅ APIService: Fetched \(calendarResponse.count) calendars")
        return calendarResponse
    }
    
    // Legacy method for compatibility
    func getConnectedProviders() async throws -> ProvidersResponse {
        let calendarResponse = try await getConnectedCalendars()
        return ProvidersResponse(providers: calendarResponse.calendars, count: calendarResponse.count)
    }
    
    func getUpcomingEvents(days: Int = 7) async throws -> EventsResponse {
        // Use the new structured GET /calendars/events/upcoming endpoint
        // This endpoint returns the same structure as GET /events
        let url = URL(string: "\(baseURL)/calendars/events/upcoming?days=\(days)")!
        #if DEBUG
        print("🌐 APIService: ===== FETCHING UPCOMING EVENTS =====")
        print("🌐 APIService: URL: \(url)")
        print("🌐 APIService: Days: \(days)")
        #endif
        
        // Check if access token is available
        guard let token = accessToken else {
            #if DEBUG
            print("❌ APIService: ERROR - No access token available! Cannot fetch events.")
            #endif
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Constants.API.timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        #if DEBUG
        print("🌐 APIService: Sending request...")
        #endif
        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        #if DEBUG
        print("🌐 APIService: Response status: \(statusCode)")
        #endif
        
        try await validateResponse(response, data: data)
        
        // Parse response with detailed error handling
        // Note: All structs (EventsResponse, CalendarEvent, EventLocation, EventAttendee, etc.)
        // have explicit CodingKeys, so we don't need keyDecodingStrategy
        let decoder = JSONDecoder()
        
        do {
            let eventsResponse = try decoder.decode(EventsResponse.self, from: data)
            #if DEBUG
            print("✅ APIService: ===== EVENTS FETCHED SUCCESSFULLY =====")
            print("✅ APIService: Total events: \(eventsResponse.totalEvents)")
            if let timeRange = eventsResponse.timeRange {
                print("✅ APIService: Time range: \(timeRange.description)")
            }
            if let summary = eventsResponse.summary {
                print("✅ APIService: Events today: \(summary.eventsToday)")
                print("✅ APIService: Events this week: \(summary.eventsThisWeek)")
            }
            print("✅ APIService: ===== END EVENTS FETCH =====")
            #endif
            
            return eventsResponse
        } catch {
            let decodingError = error as? DecodingError
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            
            #if DEBUG
            print("❌ APIService: ===== DECODING ERROR =====")
            print("❌ APIService: Failed to decode EventsResponse")
            print("❌ APIService: Error: \(error.localizedDescription)")
            
            if let decodingError = decodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("❌ APIService: Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .typeMismatch(let type, let context):
                    print("❌ APIService: Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .valueNotFound(let type, let context):
                    print("❌ APIService: Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                case .dataCorrupted(let context):
                    print("❌ APIService: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                @unknown default:
                    print("❌ APIService: Unknown decoding error")
                }
            }
            
            print("❌ APIService: Response was: \(String(responseString.prefix(500)))")
            print("❌ APIService: ===== END DECODING ERROR =====")
            #endif
            
            throw error
        }
    }
    
    // MARK: - Token Expiry Detection
    
    /// Detects if an error indicates calendar OAuth token expiry (NOT JWT token expiry)
    /// UPDATED: Now checks for new format "error": "token_expired" and old format for backward compatibility
    /// Returns true if this is a Google/Microsoft Calendar token issue, false otherwise
    private func isCalendarTokenExpiryError(_ error: Error, responseData: Data? = nil, url: URL? = nil) -> Bool {
        // Only check for calendar token expiry on calendar-related endpoints
        if let url = url {
            if !url.path.contains("/sync/google") && 
               !url.path.contains("/sync/microsoft") &&
               !url.path.contains("/sync") {
                return false // Not a calendar sync endpoint
            }
        }
        
        let errorMessage = error.localizedDescription.lowercased()
        
        // Check for calendar-specific token expiry indicators (old format)
        let calendarTokenKeywords = [
            "calendar token expired",
            "google calendar token",
            "microsoft calendar token",
            "reconnect calendar",
            "calendar connection expired"
        ]
        
        for keyword in calendarTokenKeywords {
            if errorMessage.contains(keyword) {
                return true
            }
        }
        
        // Check APIError message
        if let apiError = error as? APIError {
            let apiErrorMessage = apiError.message.lowercased()
            for keyword in calendarTokenKeywords {
                if apiErrorMessage.contains(keyword) {
                    return true
                }
            }
        }
        
        // Check response data for backend error format (NEW and OLD formats)
        if let data = responseData,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let errorType = (json["error"] as? String ?? "").lowercased()
            let errorMsg = (json["message"] as? String ?? "").lowercased()
            let actionRequired = json["action_required"] as? String ?? ""
            let provider = json["provider"] as? String ?? ""
            let status = json["status"] as? String ?? ""
            
            // NEW FORMAT: Check for "error": "token_expired"
            if errorType == "token_expired" {
                // Verify it's a calendar provider (not JWT token)
                if provider == "google" || provider == "microsoft" {
                    return true
                }
            }
            
            // OLD FORMAT: Backward compatibility
            if (provider == "google" || provider == "microsoft") &&
               (errorMsg.contains("calendar token") || 
                errorMsg.contains("reconnect calendar") ||
                actionRequired == "reconnect_calendar" ||
                (status == "error" && errorMsg.contains("token expired"))) {
                return true
            }
        }
        
        // Check NSError userInfo
        if let nsError = error as NSError? {
            if let userInfo = nsError.userInfo as? [String: Any] {
                let errorMsg = (userInfo[NSLocalizedDescriptionKey] as? String ?? "").lowercased()
                for keyword in calendarTokenKeywords {
                    if errorMsg.contains(keyword) {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    /// Detects if an error is a transient failure (retryable)
    /// NEW: Checks for "error": "transient_failure" format
    /// Returns (isTransient: Bool, retryable: Bool, message: String?)
    private func isTransientFailureError(responseData: Data?) -> (isTransient: Bool, retryable: Bool, message: String?) {
        guard let data = responseData,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (false, false, nil)
        }
        
        let errorType = (json["error"] as? String ?? "").lowercased()
        
        // NEW FORMAT: Check for "error": "transient_failure"
        if errorType == "transient_failure" {
            let retryable = json["retryable"] as? Bool ?? true
            let message = json["message"] as? String
            return (true, retryable, message)
        }
        
        return (false, false, nil)
    }
    
    /// Extracts calendar token expiry details from error response
    /// UPDATED: Supports both new and old error formats
    private func extractCalendarTokenExpiryDetails(from data: Data?, statusCode: Int) -> (provider: String, errorMessage: String) {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ("unknown", "Calendar token expired")
        }
        
        // NEW FORMAT: "error": "token_expired"
        if let errorType = json["error"] as? String, errorType == "token_expired" {
            let provider = json["provider"] as? String ?? "unknown"
            let message = json["message"] as? String ?? "Calendar token expired or revoked. User must reconnect."
            return (provider, message)
        }
        
        // OLD FORMAT: Backward compatibility
        let provider = json["provider"] as? String ?? "unknown"
        let message = json["message"] as? String ?? json["error"] as? String ?? "Calendar token expired"
        return (provider, message)
    }
    
    func syncGoogleCalendar() async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/sync/google")!
        print("🌐 APIService: ===== SYNCING GOOGLE CALENDAR =====")
        print("🌐 APIService: URL: \(url)")
        
        guard let token = accessToken else {
            print("❌ APIService: ERROR - No access token available for sync!")
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = Constants.API.timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🌐 APIService: Sending sync request with token: \(token.prefix(20))...")
        
        let (data, response): (Data, URLResponse) = try await {
            do {
                let result = try await session.data(for: request)
                let statusCode = (result.1 as? HTTPURLResponse)?.statusCode ?? -1
                print("🌐 APIService: Sync response status: \(statusCode)")
                
                let responseString = String(data: result.0, encoding: .utf8) ?? "No response body"
                print("🌐 APIService: ===== RAW SYNC RESPONSE =====")
                print("🌐 APIService: \(responseString)")
                
                try await validateResponse(result.1, data: result.0)
                return result
            } catch let error as APIError where error.code == "401_REFRESHED" {
                // Token was refreshed, retry the sync request with new token
                print("🔄 APIService: Token refreshed - retrying syncGoogleCalendar...")
                guard let newToken = accessToken else {
                    throw NSError(
                        domain: "AllTime",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
                    )
                }
                
                var retryRequest = URLRequest(url: url)
                retryRequest.httpMethod = "POST"
                retryRequest.timeoutInterval = Constants.API.timeout
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                retryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                print("🌐 APIService: Retrying sync request with new token: \(newToken.prefix(20))...")
                let result = try await session.data(for: retryRequest)
                
                let statusCode = (result.1 as? HTTPURLResponse)?.statusCode ?? -1
                print("🌐 APIService: Retry sync response status: \(statusCode)")
                
                let responseString = String(data: result.0, encoding: .utf8) ?? "No response body"
                print("🌐 APIService: ===== RAW SYNC RESPONSE (RETRY) =====")
                print("🌐 APIService: \(responseString)")
                
                try await validateResponse(result.1, data: result.0)
                return result
            } catch let apiError as APIError {
                // Check if this is a token expiry error from validateResponse
                let responseData: Data?
                let statusCode: Int
                
                // Try to extract response data from the error if available
                if let details = apiError.details,
                   let data = details.data(using: .utf8) {
                    responseData = data
                } else {
                    responseData = nil
                }
                
                statusCode = Int(apiError.code ?? "0") ?? 0
                
                // Check if this is a calendar token expiry (already handled in validateResponse)
                // Just re-throw the APIError
                throw apiError
            } catch {
                // Check if this is a calendar token expiry error from other error types
                if isCalendarTokenExpiryError(error, responseData: nil, url: url) {
                    print("❌ APIService: ===== CALENDAR TOKEN EXPIRY DETECTED =====")
                    print("❌ APIService: Calendar token expired - triggering reconnection flow")
                    
                    // Determine which provider
                    let provider = url.path.contains("microsoft") ? "Microsoft" : "Google"
                    let notificationName = url.path.contains("microsoft") ? 
                        NSNotification.Name("MicrosoftCalendarTokenExpired") :
                        NSNotification.Name("GoogleCalendarTokenExpired")
                    
                    // Post notification to trigger reconnection
                    NotificationCenter.default.post(
                        name: notificationName,
                        object: nil,
                        userInfo: ["error": error.localizedDescription, "provider": provider]
                    )
                    
                    if let nsError = error as NSError? {
                        throw NSError(
                            domain: nsError.domain,
                            code: nsError.code,
                            userInfo: [
                                NSLocalizedDescriptionKey: "\(provider) Calendar connection expired. Please reconnect your calendar.",
                                "requires_reconnection": true,
                                "provider": provider,
                                "original_error": error
                            ]
                        )
                    }
                }
                
                // Re-throw other errors
                throw error
            }
        }()
        
        // Use standard decoder - SyncResponse has explicit CodingKeys for field mapping
        // Note: When using explicit CodingKeys, keyDecodingStrategy is ignored
        let decoder = JSONDecoder()
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        
        do {
            let syncResponse = try decoder.decode(SyncResponse.self, from: data)
            print("✅ APIService: ===== SYNC RESPONSE DECODED =====")
            print("✅ APIService: Status: \(syncResponse.status)")
            print("✅ APIService: Message: \(syncResponse.message)")
            print("✅ APIService: User ID: \(syncResponse.userId)")
            print("✅ APIService: Events Synced: \(syncResponse.eventsSynced)")
            print("✅ APIService: ===== END SYNC RESPONSE =====")
            
            if syncResponse.eventsSynced == 0 {
                print("⚠️ APIService: ===== WARNING: SYNC RETURNED 0 EVENTS =====")
                print("⚠️ APIService: This means:")
                print("   - Either Google Calendar has no events in the sync date range")
                print("   - Or backend couldn't fetch events from Google Calendar")
                print("   - Or events exist but backend didn't sync them")
                print("⚠️ APIService: Check backend logs to see what Google Calendar API returned")
                print("⚠️ APIService: The backend should now check ALL calendars, not just 'primary'")
            } else {
                print("✅ APIService: SUCCESS - \(syncResponse.eventsSynced) events were synced from Google Calendar")
            }
            
            return syncResponse
        } catch let decodingError as DecodingError {
            print("❌ APIService: ===== DECODING ERROR =====")
            print("❌ APIService: Failed to decode sync response: \(decodingError)")
            
            // Log detailed decoding error information
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("❌ APIService: Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                print("❌ APIService: Context: \(context.debugDescription)")
            case .typeMismatch(let type, let context):
                print("❌ APIService: Type mismatch - expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                print("❌ APIService: Value not found - expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                print("❌ APIService: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            @unknown default:
                print("❌ APIService: Unknown decoding error: \(decodingError)")
            }
            
            print("❌ APIService: Response was: \(responseString)")
            
            // Re-throw with a more descriptive error
            throw NSError(
                domain: "AllTime",
                code: 1002,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to decode sync response: \(decodingError.localizedDescription)",
                    "rawResponse": responseString,
                    "underlyingError": decodingError
                ]
            )
        } catch {
            print("❌ APIService: Failed to decode sync response: \(error)")
            print("❌ APIService: Response was: \(responseString)")
            throw error
        }
    }
    
    func syncProvider(_ providerId: Int) async throws -> SyncResponse {
        // For now, only Google sync is supported
        return try await syncGoogleCalendar()
    }

    // MARK: - Connection Health Check

    /// Response model for connection health check
    struct ConnectionHealthResponse: Codable {
        let healthy: Bool
        let needsReconnect: Bool
        let connections: [ConnectionDetail]
        let userMessage: String?
        let actionUrl: String?

        struct ConnectionDetail: Codable {
            let provider: String
            let email: String?
            let status: String
            let needsReconnect: Bool
            let lastSyncAt: String?
            let lastError: String?
            let actionRequired: String?
            let actionMessage: String?

            enum CodingKeys: String, CodingKey {
                case provider, email, status
                case needsReconnect = "needs_reconnect"
                case lastSyncAt = "last_sync_at"
                case lastError = "last_error"
                case actionRequired = "action_required"
                case actionMessage = "action_message"
            }
        }

        enum CodingKeys: String, CodingKey {
            case healthy
            case needsReconnect = "needs_reconnect"
            case connections
            case userMessage = "user_message"
            case actionUrl = "action_url"
        }
    }

    /// Check connection health and trigger reconnection flow if needed.
    /// Call this on app launch and periodically to proactively detect connection issues.
    /// - Returns: ConnectionHealthResponse with status of all calendar connections
    func checkConnectionHealth() async throws -> ConnectionHealthResponse {
        let url = URL(string: "\(baseURL)/sync/connection-health")!
        print("🏥 APIService: ===== CHECKING CONNECTION HEALTH =====")

        guard let token = accessToken else {
            print("⚠️ APIService: No access token - user not signed in")
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not signed in"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10 // Quick timeout for health check
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        if httpResponse.statusCode == 401 {
            // User token expired, need to re-authenticate
            try await validateResponse(response, data: data)
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "AllTime",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: errorMsg]
            )
        }

        let healthResponse = try JSONDecoder().decode(ConnectionHealthResponse.self, from: data)

        print("🏥 APIService: Health check result - healthy: \(healthResponse.healthy), needs_reconnect: \(healthResponse.needsReconnect)")

        // If any connection needs reconnection, post the appropriate notification
        if healthResponse.needsReconnect {
            for connection in healthResponse.connections where connection.needsReconnect {
                print("⚠️ APIService: Connection \(connection.provider) needs reconnection: \(connection.lastError ?? "Unknown error")")

                let notificationName = connection.provider.lowercased() == "microsoft" ?
                    NSNotification.Name("MicrosoftCalendarTokenExpired") :
                    NSNotification.Name("GoogleCalendarTokenExpired")

                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: notificationName,
                        object: nil,
                        userInfo: [
                            "provider": connection.provider,
                            "message": connection.actionMessage ?? "Please reconnect your calendar",
                            "lastError": connection.lastError ?? ""
                        ]
                    )
                }
            }
        }

        return healthResponse
    }

    /// Disconnect/remove a calendar connection by provider name
    /// - Parameter provider: "google" or "microsoft" (case-insensitive)
    /// - Returns: DeleteCalendarResponse with status and message
    /// - Throws: APIError on failure
    func disconnectProvider(_ provider: String) async throws -> DeleteCalendarResponse {
        // Validate provider
        let providerLower = provider.lowercased()
        guard providerLower == "google" || providerLower == "microsoft" else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Provider must be 'google' or 'microsoft'"]
            )
        }
        
        let url = URL(string: "\(baseURL)/calendars/\(providerLower)")!
        print("🗑️ APIService: ===== DISCONNECTING CALENDAR =====")
        print("🗑️ APIService: Provider: \(providerLower)")
        print("🗑️ APIService: URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.timeoutInterval = Constants.API.timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authorization header
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🌐 APIService: Sending DELETE request to \(url)")
        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("📥 APIService: Response status: \(statusCode)")
        
        // Log response body for debugging
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("📥 APIService: Response body: \(responseString)")
        
        // Handle specific status codes
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                // Success - decode response
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let deleteResponse = try decoder.decode(DeleteCalendarResponse.self, from: data)
                    print("✅ APIService: ===== CALENDAR DISCONNECTED SUCCESSFULLY =====")
                    print("✅ APIService: Status: \(deleteResponse.status)")
                    print("✅ APIService: Message: \(deleteResponse.message)")
                    print("✅ APIService: Provider: \(deleteResponse.provider)")
                    return deleteResponse
                } catch {
                    print("❌ APIService: Failed to decode delete response: \(error)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"]
                    )
                }
                
            case 401:
                print("❌ APIService: Authentication failed - token expired or invalid")
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
                )
                
            case 404:
                print("❌ APIService: Calendar connection not found")
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Calendar connection not found"]
                )
                
            case 400:
                print("❌ APIService: Invalid provider or bad request")
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid request"]
                )
                
            default:
                // Try to parse error message
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to disconnect calendar"]
                )
            }
        }
        
        // Fallback validation
        try await validateResponse(response, data: data)
        
        // If we get here, decode the response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(DeleteCalendarResponse.self, from: data)
    }
    
    // MARK: - Event Details
    
    /// Fetch detailed event information by event ID
    /// - Parameter eventId: The event ID from the event list
    /// - Returns: EventDetails with complete event information including attendees
    /// - Throws: APIError on failure
    func getEventDetails(eventId: Int64) async throws -> EventDetails {
        let url = URL(string: "\(baseURL)/calendars/events/\(eventId)")!
        print("📋 APIService: ===== FETCHING EVENT DETAILS =====")
        print("📋 APIService: Event ID: \(eventId)")
        print("📋 APIService: URL: \(url)")
        
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        print("🌐 APIService: Sending GET request to \(url)")
        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("📥 APIService: Response status: \(statusCode)")
        
        // Log response body for debugging
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("📥 APIService: Response body: \(responseString)")
        
        // Parse JSON to analyze what backend is actually sending
        if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            print("📋 APIService: ===== BACKEND RESPONSE FIELD ANALYSIS =====")
            print("📋 APIService: Raw JSON Fields Present:")
            print("   - id: \(jsonDict["id"] != nil ? "✅ Present (\(jsonDict["id"] ?? "nil"))" : "❌ Missing")")
            print("   - title: \(jsonDict["title"] != nil ? "✅ Present (\(jsonDict["title"] ?? "nil"))" : "❌ Missing")")
            print("   - description: \(jsonDict["description"] != nil ? "✅ Present (\(jsonDict["description"] ?? "nil"))" : "❌ Missing")")
            print("   - location: \(jsonDict["location"] != nil ? "✅ Present (\(jsonDict["location"] ?? "nil"))" : "❌ Missing")")
            print("   - start_time: \(jsonDict["start_time"] != nil ? "✅ Present (\(jsonDict["start_time"] ?? "nil"))" : "❌ Missing")")
            print("   - end_time: \(jsonDict["end_time"] != nil ? "✅ Present (\(jsonDict["end_time"] ?? "nil"))" : "❌ Missing")")
            print("   - all_day: \(jsonDict["all_day"] != nil ? "✅ Present (\(jsonDict["all_day"] ?? "nil"))" : "❌ Missing")")
            print("   - source: \(jsonDict["source"] != nil ? "✅ Present (\(jsonDict["source"] ?? "nil"))" : "❌ Missing")")
            print("   - source_event_id: \(jsonDict["source_event_id"] != nil ? "✅ Present (\(jsonDict["source_event_id"] ?? "nil"))" : "❌ Missing")")
            print("   - attendees: \(jsonDict["attendees"] != nil ? "✅ Present" : "❌ Missing")")
            if let attendeesArray = jsonDict["attendees"] as? [[String: Any]] {
                print("   - Attendees Array: \(attendeesArray.count) items")
                for (index, attendee) in attendeesArray.enumerated() {
                    print("     [\(index)] Fields:")
                    print("       - email: \(attendee["email"] != nil ? "✅ (\(attendee["email"] ?? "nil"))" : "❌ Missing")")
                    print("       - displayName: \(attendee["displayName"] != nil ? "✅ (\(attendee["displayName"] ?? "nil"))" : (attendee["display_name"] != nil ? "⚠️ Using display_name: \(attendee["display_name"] ?? "nil")" : "❌ Missing"))")
                    print("       - name: \(attendee["name"] != nil ? "⚠️ Using name: \(attendee["name"] ?? "nil")" : "❌ Missing")")
                    print("       - responseStatus: \(attendee["responseStatus"] != nil ? "✅ (\(attendee["responseStatus"] ?? "nil"))" : (attendee["response_status"] != nil ? "⚠️ Using response_status: \(attendee["response_status"] ?? "nil")" : "❌ Missing"))")
                    print("       - All keys in attendee: \(attendee.keys.joined(separator: ", "))")
                }
            } else if let attendeesArray = jsonDict["attendees"] as? [Any] {
                print("   - Attendees Array: \(attendeesArray.count) items (type: \(type(of: attendeesArray)))")
            } else if jsonDict["attendees"] == nil {
                print("   - Attendees: ❌ Field is nil (not present in response)")
            } else {
                print("   - Attendees: ⚠️ Unexpected type: \(type(of: jsonDict["attendees"]!))")
            }
            print("   - is_cancelled: \(jsonDict["is_cancelled"] != nil ? "✅ Present (\(jsonDict["is_cancelled"] ?? "nil"))" : "❌ Missing")")
            print("   - created_at: \(jsonDict["created_at"] != nil ? "✅ Present (\(jsonDict["created_at"] ?? "nil"))" : "❌ Missing")")
            print("   - user_id: \(jsonDict["user_id"] != nil ? "✅ Present (\(jsonDict["user_id"] ?? "nil"))" : "❌ Missing")")
            
            // Check for empty strings
            print("📋 APIService: Field Values Analysis:")
            if let description = jsonDict["description"] as? String {
                print("   - description value: '\(description)' (isEmpty: \(description.isEmpty), length: \(description.count))")
            }
            if let location = jsonDict["location"] as? String {
                print("   - location value: '\(location)' (isEmpty: \(location.isEmpty), length: \(location.count))")
            }
            if let attendeesArray = jsonDict["attendees"] as? [[String: Any]] {
                print("   - attendees count: \(attendeesArray.count)")
            }
        }
        
        // Handle specific status codes
        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200:
                // Success - decode response
                // Note: EventDetails uses explicit CodingKeys for snake_case fields
                // Attendees may use either camelCase (displayName, responseStatus) or snake_case (display_name, response_status)
                // The Attendee model's custom decoder handles both formats
                let decoder = JSONDecoder()
                
                do {
                    let eventDetails = try decoder.decode(EventDetails.self, from: data)
                    print("✅ APIService: ===== EVENT DETAILS FETCHED SUCCESSFULLY =====")
                    print("✅ APIService: Event ID: \(eventDetails.id)")
                    print("✅ APIService: Title: \(eventDetails.title ?? "nil")")
                    print("✅ APIService: Description: \(eventDetails.description ?? "nil") (isEmpty: \(eventDetails.description?.isEmpty ?? true))")
                    print("✅ APIService: Location: \(eventDetails.location ?? "nil") (isEmpty: \(eventDetails.location?.isEmpty ?? true))")
                    print("✅ APIService: Start Time: \(eventDetails.startTime)")
                    print("✅ APIService: End Time: \(eventDetails.endTime)")
                    print("✅ APIService: All Day: \(eventDetails.allDay)")
                    print("✅ APIService: Source: \(eventDetails.source)")
                    print("✅ APIService: Source Event ID: \(eventDetails.sourceEventId)")
                    print("✅ APIService: Attendees Count: \(eventDetails.attendees?.count ?? 0)")
                    if let attendees = eventDetails.attendees, !attendees.isEmpty {
                        print("✅ APIService: Attendees Details:")
                        for (index, attendee) in attendees.enumerated() {
                            print("   [\(index)] Email: \(attendee.email ?? "nil"), Name: \(attendee.displayName ?? "nil"), Status: \(attendee.responseStatus ?? "nil")")
                        }
                    } else {
                        print("⚠️ APIService: Attendees array is empty or nil")
                    }
                    print("✅ APIService: Is Cancelled: \(eventDetails.isCancelled)")
                    print("✅ APIService: Created At: \(eventDetails.createdAt)")
                    print("✅ APIService: User ID: \(eventDetails.userId)")
                    print("📋 APIService: ===== BACKEND RESPONSE ANALYSIS =====")
                    print("📋 APIService: Fields with data:")
                    print("   - Title: \(eventDetails.title != nil && !(eventDetails.title?.isEmpty ?? true) ? "✅ Has data" : "❌ Empty/nil")")
                    print("   - Description: \(eventDetails.description != nil && !(eventDetails.description?.isEmpty ?? true) ? "✅ Has data" : "❌ Empty/nil")")
                    print("   - Location: \(eventDetails.location != nil && !(eventDetails.location?.isEmpty ?? true) ? "✅ Has data" : "❌ Empty/nil")")
                    print("   - Attendees: \(eventDetails.attendees != nil && !(eventDetails.attendees?.isEmpty ?? true) ? "✅ Has \(eventDetails.attendees?.count ?? 0) attendees" : "❌ Empty/nil")")
                    return eventDetails
                } catch {
                    print("❌ APIService: Failed to decode event details: \(error)")
                    print("❌ APIService: Response was: \(responseString)")
                    
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("❌ APIService: Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        case .typeMismatch(let type, let context):
                            print("❌ APIService: Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        case .valueNotFound(let type, let context):
                            print("❌ APIService: Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        case .dataCorrupted(let context):
                            print("❌ APIService: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                        @unknown default:
                            print("❌ APIService: Unknown decoding error")
                        }
                    }
                    
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode event details: \(error.localizedDescription)",
                            "rawResponse": responseString,
                            "underlyingError": error
                        ]
                    )
                }
                
            case 401:
                print("❌ APIService: Authentication failed - token expired or invalid")
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: 401,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
                )
                
            case 404:
                print("❌ APIService: Event not found")
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Event not found"]
                )
                
            case 403:
                print("❌ APIService: Access forbidden")
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 403,
                    userInfo: [NSLocalizedDescriptionKey: "You don't have access to this event"]
                )
                
            default:
                // Try to parse error message
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    throw NSError(
                        domain: "AllTime",
                        code: httpResponse.statusCode,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to fetch event details"]
                )
            }
        }
        
        // Fallback validation
        try await validateResponse(response, data: data)
        
        // If we get here, decode the response
        // Note: EventDetails uses explicit CodingKeys, so we don't need keyDecodingStrategy
        let decoder = JSONDecoder()
        return try decoder.decode(EventDetails.self, from: data)
    }
    
    // MARK: - Helper Methods
    
    /// Attempts to refresh the access token if a 401 error occurs
    private func attemptTokenRefresh() async -> Bool {
        refreshLock.lock()
        
        // If already refreshing, wait for it to complete
        if isRefreshingToken {
            refreshLock.unlock()
            print("🔄 APIService: Token refresh already in progress, waiting...")
            // Wait a bit for the refresh to complete
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return KeychainManager.shared.getAccessToken() != nil
        }
        
        isRefreshingToken = true
        refreshLock.unlock()
        
        defer {
            refreshLock.lock()
            isRefreshingToken = false
            refreshLock.unlock()
        }
        
        print("🔄 APIService: Attempting to refresh access token...")
        
        guard let refreshToken = KeychainManager.shared.getRefreshToken() else {
            print("❌ APIService: No refresh token available")
            // Trigger sign out
            NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
            return false
        }
        
        do {
            let refreshResponse = try await self.refreshToken(refreshToken: refreshToken)
            
            // Store new access token
            let success = KeychainManager.shared.store(key: "access_token", value: refreshResponse.accessToken)
            
            if success {
                print("✅ APIService: Token refreshed successfully")
                return true
            } else {
                print("❌ APIService: Failed to store refreshed token")
                // Trigger sign out
                NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
                return false
            }
        } catch {
            print("❌ APIService: Token refresh failed: \(error.localizedDescription)")
            // Refresh token is invalid - trigger sign out (already done in refreshToken method)
            return false
        }
    }
    
    private func validateResponse(_ response: URLResponse, data: Data? = nil) async throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ APIService: ===== VALIDATION ERROR =====")
            print("❌ APIService: Invalid response - not HTTPURLResponse")
            throw APIError(message: "Invalid response", code: nil, details: nil)
        }
        
        print("🌐 APIService: ===== RESPONSE VALIDATION =====")
        print("🌐 APIService: HTTP Status Code: \(httpResponse.statusCode)")
        print("🌐 APIService: Response Headers: \(httpResponse.allHeaderFields)")
        
        guard 200...299 ~= httpResponse.statusCode else {
            // Special handling for 401 - attempt token refresh
            // BUT: Don't refresh if this is already a refresh token request (would cause infinite loop)
            // AND: Don't refresh for health check endpoint (it shouldn't require auth)
            // AND: Don't refresh JWT token if this is a calendar token expiry (different issue)
            if httpResponse.statusCode == 401 {
                // Check if this is a refresh token endpoint by checking the URL
                if let url = httpResponse.url, url.path.contains("/auth/refresh") {
                    // This is the refresh endpoint itself - don't try to refresh again
                    print("❌ APIService: Refresh token endpoint returned 401 - refresh token is invalid")
                    NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
                } else if let url = httpResponse.url, url.path.contains("/health") {
                    // Health check shouldn't require auth - just throw the error
                    print("⚠️ APIService: Health check returned 401 - backend may require auth (unexpected)")
                } else {
                    // Check if this is a calendar token expiry (not JWT token expiry)
                    // UPDATED: Supports new format "error": "token_expired"
                    var isCalendarTokenIssue = false
                    if let data = data,
                       let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let errorType = (errorJSON["error"] as? String ?? "").lowercased()
                        let errorMsg = (errorJSON["message"] as? String ?? "").lowercased()
                        let actionRequired = errorJSON["action_required"] as? String ?? ""
                        let provider = errorJSON["provider"] as? String ?? ""
                        
                        // NEW FORMAT: Check for "error": "token_expired"
                        if errorType == "token_expired" && (provider == "google" || provider == "microsoft") {
                            isCalendarTokenIssue = true
                            print("🔄 APIService: This is a calendar token expiry (NEW FORMAT) - skipping JWT refresh")
                        }
                        // OLD FORMAT: Backward compatibility
                        else if (provider == "google" || provider == "microsoft") &&
                           (errorMsg.contains("calendar token") || 
                            errorMsg.contains("reconnect calendar") ||
                            actionRequired == "reconnect_calendar") {
                            isCalendarTokenIssue = true
                            print("🔄 APIService: This is a calendar token expiry (OLD FORMAT) - skipping JWT refresh")
                        }
                    }
                    
                    // Only attempt JWT token refresh if this is NOT a calendar token issue
                    if !isCalendarTokenIssue {
                        print("🔄 APIService: Received 401 - attempting JWT token refresh...")
                        
                        // Attempt to refresh token
                        if await attemptTokenRefresh() {
                            print("✅ APIService: Token refreshed successfully - throwing special error for retry")
                            // Throw a special error that indicates token was refreshed
                            // The caller should retry the request
                            throw APIError(message: "Token expired - refreshed, please retry", code: "401_REFRESHED", details: nil)
                        } else {
                            print("❌ APIService: JWT token refresh failed - signing out")
                            // JWT token refresh failed - trigger sign out
                            NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
                        }
                    } else {
                        print("🔄 APIService: Calendar token expiry detected - NOT refreshing JWT token")
                        // Calendar token expiry is handled separately - don't sign out
                    }
                }
            }
            
            let errorMessage = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            print("❌ APIService: ===== HTTP ERROR =====")
            print("❌ APIService: Status Code: \(httpResponse.statusCode)")
            print("❌ APIService: Error Message: \(errorMessage)")
            print("❌ APIService: All Headers: \(httpResponse.allHeaderFields)")
            
            // Try to parse error response body
            var backendError = errorMessage
            var backendErrorDetails: String? = nil
            
            if let data = data {
                // First try to parse as JSON to extract structured error message
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("❌ APIService: Backend Error JSON: \(errorJSON)")
                    
                    // Extract message field (most descriptive)
                    if let message = errorJSON["message"] as? String {
                        backendError = message
                        print("❌ APIService: Extracted error message: \(message)")
                    } else if let error = errorJSON["error"] as? String {
                        backendError = error
                        print("❌ APIService: Extracted error: \(error)")
                    }
                    
                    // Store full error details
                    if let errorDetails = try? JSONSerialization.data(withJSONObject: errorJSON, options: .prettyPrinted),
                       let errorString = String(data: errorDetails, encoding: .utf8) {
                        backendErrorDetails = errorString
                    }
                    
                    // UPDATED: Check for token expiry in new format "error": "token_expired"
                    // Also check for transient failures "error": "transient_failure"
                    let errorType = (errorJSON["error"] as? String ?? "").lowercased()
                    let provider = errorJSON["provider"] as? String ?? ""
                    
                    // NEW FORMAT: Token expired
                    if errorType == "token_expired" && (provider == "google" || provider == "microsoft") {
                        print("❌ APIService: ===== TOKEN EXPIRY DETECTED (NEW FORMAT) =====")
                        print("❌ APIService: Calendar token expired - triggering reconnection flow")
                        
                        let notificationName = provider == "microsoft" ?
                            NSNotification.Name("MicrosoftCalendarTokenExpired") :
                            NSNotification.Name("GoogleCalendarTokenExpired")
                        
                        NotificationCenter.default.post(
                            name: notificationName,
                            object: nil,
                            userInfo: ["error": backendError, "provider": provider]
                        )
                        
                        throw APIError(
                            message: backendError,
                            code: String(httpResponse.statusCode),
                            details: backendErrorDetails
                        )
                    }
                    // NEW FORMAT: Transient failure (500 status)
                    else if errorType == "transient_failure" && httpResponse.statusCode == 500 {
                        let retryable = errorJSON["retryable"] as? Bool ?? true
                        print("⚠️ APIService: ===== TRANSIENT FAILURE DETECTED =====")
                        print("⚠️ APIService: Transient failure - retryable: \(retryable)")
                        print("⚠️ APIService: Provider: \(provider)")
                        print("⚠️ APIService: Message: \(backendError)")
                        
                        // Throw NSError for transient failures (supports userInfo better)
                        throw NSError(
                            domain: "AllTime",
                            code: 500,
                            userInfo: [
                                NSLocalizedDescriptionKey: backendError,
                                "error_type": "transient_failure",
                                "retryable": retryable,
                                "provider": provider,
                                "code": "TRANSIENT_FAILURE"
                            ]
                        )
                    }
                    // OLD FORMAT: Backward compatibility for sync/google endpoint
                    else if let url = httpResponse.url, url.path.contains("/sync/google") || url.path.contains("/sync/microsoft") {
                        let errorMsg = backendError.lowercased()
                        let actionRequired = errorJSON["action_required"] as? String ?? ""
                        
                        if errorMsg.contains("token expired") ||
                           errorMsg.contains("invalid_grant") ||
                           errorMsg.contains("refresh failed") ||
                           errorMsg.contains("reconnect calendar") ||
                           errorMsg.contains("calendar token expired") ||
                           actionRequired == "reconnect_calendar" {
                            print("❌ APIService: ===== TOKEN EXPIRY DETECTED IN SYNC (OLD FORMAT) =====")
                            print("❌ APIService: Calendar token expired - triggering reconnection flow")
                            
                            let notificationName = provider == "microsoft" ?
                                NSNotification.Name("MicrosoftCalendarTokenExpired") :
                                NSNotification.Name("GoogleCalendarTokenExpired")
                            
                            NotificationCenter.default.post(
                                name: notificationName,
                                object: nil,
                                userInfo: ["error": backendError, "provider": provider]
                            )
                            
                            throw APIError(
                                message: backendError,
                                code: String(httpResponse.statusCode),
                                details: backendErrorDetails
                            )
                        }
                    }
                } else if let errorString = String(data: data, encoding: .utf8) {
                    // Fallback to plain string
                    print("❌ APIService: Backend Error Response (plain text): \(errorString)")
                    backendError = errorString
                    
                    // Check for calendar token expiry in plain text response for sync endpoints
                    if let url = httpResponse.url, 
                       (url.path.contains("/sync/google") || url.path.contains("/sync/microsoft")) {
                        let errorMsg = backendError.lowercased()
                        
                        // Check if this is specifically about calendar token
                        if errorMsg.contains("calendar token") ||
                           errorMsg.contains("reconnect calendar") {
                            let provider = url.path.contains("microsoft") ? "microsoft" : "google"
                            print("❌ APIService: ===== CALENDAR TOKEN EXPIRY DETECTED IN SYNC (PLAIN TEXT) =====")
                            print("❌ APIService: \(provider.capitalized) Calendar token expired - triggering reconnection flow")
                            
                            // Determine notification name based on provider
                            let notificationName = provider == "microsoft" ?
                                NSNotification.Name("MicrosoftCalendarTokenExpired") :
                                NSNotification.Name("GoogleCalendarTokenExpired")
                            
                            // Post notification to trigger reconnection (NOT sign-out)
                            NotificationCenter.default.post(
                                name: notificationName,
                                object: nil,
                                userInfo: ["error": backendError, "provider": provider]
                            )
                            
                            throw APIError(
                                message: "\(provider.capitalized) Calendar connection expired. Please reconnect your calendar.",
                                code: String(httpResponse.statusCode),
                                details: backendErrorDetails
                            )
                        }
                    }
                } else {
                    print("❌ APIService: No response body data available")
                }
            } else {
                print("❌ APIService: No response data available")
            }
            
            print("❌ APIService: Throwing APIError with message: \(backendError)")
            throw APIError(message: backendError, code: String(httpResponse.statusCode), details: backendErrorDetails)
        }
        
        print("✅ APIService: Response validation successful")
    }
    
    // MARK: - Event Creation
    
    /// Create a new calendar event in the selected calendar with optional attendee invites
    /// - Parameters:
    ///   - title: Event title (required)
    ///   - description: Event description (optional)
    ///   - location: Event location (optional)
    ///   - startDate: Event start time (Date object - will be converted to UTC)
    ///   - endDate: Event end time (Date object - will be converted to UTC)
    ///   - isAllDay: Whether event is all-day
    ///   - provider: Optional - "google" or "microsoft" to create in specific calendar. nil = local only
    ///   - attendees: Optional - Array of email addresses to send invites to
    /// - Returns: CreateEventResponse with sync status showing which calendar it was synced to
    func createEvent(
        title: String,
        description: String?,
        location: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        provider: String? = nil,
        attendees: [String]? = nil
    ) async throws -> CreateEventResponse {
        let url = URL(string: "\(baseURL)/calendars/events")!
        print("📝 APIService: ===== CREATING EVENT =====")
        print("📝 APIService: Title: '\(title)'")
        print("📝 APIService: URL: \(url)")
        
        // Validate required fields
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Title is required"]
            )
        }
        
        guard endDate > startDate else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "End time must be after start time"]
            )
        }
        
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        // Convert local dates to UTC ISO 8601 format
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // UTC
        
        let startTimeString = formatter.string(from: startDate)
        let endTimeString = formatter.string(from: endDate)
        
        print("📅 APIService: Start time (UTC): \(startTimeString)")
        print("📅 APIService: End time (UTC): \(endTimeString)")
        print("📅 APIService: All day: \(isAllDay)")
        
        // Build request body using CreateEventRequest model
        let requestBody = CreateEventRequest(
            title: title,
            description: description?.isEmpty == false ? description : nil,
            location: location?.isEmpty == false ? location : nil,
            startTime: startTimeString,
            endTime: endTimeString,
            allDay: isAllDay,
            provider: provider,
            attendees: attendees?.isEmpty == false ? attendees : nil
        )
        
        print("📝 APIService: Provider: \(provider ?? "local")")
        if let attendees = attendees, !attendees.isEmpty {
            print("📝 APIService: Attendees: \(attendees.joined(separator: ", "))")
        }
        
        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
            
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 APIService: Request body: \(bodyString)")
            }
        } catch {
            print("❌ APIService: Failed to encode request: \(error)")
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Failed to encode request: \(error.localizedDescription)"]
            )
        }
        
        print("🌐 APIService: Sending POST request to \(url)")
        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("📥 APIService: Response status: \(statusCode)")
        
        // Log response body for debugging
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("📥 APIService: Response body: \(responseString)")
        
        // Handle specific status codes
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 {
                print("❌ APIService: Authentication failed - token expired or invalid")
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
                )
            }
            
            if httpResponse.statusCode == 400 {
                // Try to parse error message from response
                if let errorJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorJSON["message"] as? String {
                    print("❌ APIService: Validation error: \(message)")
                    throw NSError(
                        domain: "AllTime",
                        code: 400,
                        userInfo: [NSLocalizedDescriptionKey: message]
                    )
                }
                throw NSError(
                    domain: "AllTime",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid request data"]
                )
            }
        }
        
        try await validateResponse(response, data: data)
        
        // Parse response using CreateEventResponse model
        // Note: Don't use keyDecodingStrategy since CreateEventResponse has explicit CodingKeys
        let decoder = JSONDecoder()
        
        do {
            let eventResponse = try decoder.decode(CreateEventResponse.self, from: data)
            
            print("✅ APIService: ===== EVENT CREATED SUCCESSFULLY =====")
            print("✅ APIService: Event ID: \(eventResponse.id)")
            print("✅ APIService: Title: \(eventResponse.title)")
            print("✅ APIService: Provider: \(eventResponse.syncStatus.provider)")
            print("✅ APIService: Synced: \(eventResponse.syncStatus.synced)")
            
            if let eventId = eventResponse.syncStatus.eventId {
                print("✅ APIService: External event ID: \(eventId)")
            }
            
            if let attendeesCount = eventResponse.syncStatus.attendeesCount {
                print("✅ APIService: Attendees count: \(attendeesCount)")
            }
            
            if let attendees = eventResponse.syncStatus.attendees, !attendees.isEmpty {
                print("✅ APIService: Attendees: \(attendees.joined(separator: ", "))")
            }
            
            if let meetingLink = eventResponse.syncStatus.meetingLink, !meetingLink.isEmpty {
                print("✅ APIService: Meeting link: \(meetingLink)")
            }
            
            if let meetingType = eventResponse.syncStatus.meetingType {
                print("✅ APIService: Meeting type: \(meetingType)")
            }
            
            return eventResponse
            
        } catch let decodingError as DecodingError {
            print("❌ APIService: ===== DECODING ERROR =====")
            print("❌ APIService: Failed to decode CreateEventResponse: \(decodingError)")
            print("❌ APIService: Response was: \(responseString)")
            
            // Log detailed decoding error
            switch decodingError {
            case .keyNotFound(let key, let context):
                print("❌ APIService: Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .typeMismatch(let type, let context):
                print("❌ APIService: Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .valueNotFound(let type, let context):
                print("❌ APIService: Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            case .dataCorrupted(let context):
                print("❌ APIService: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            @unknown default:
                print("❌ APIService: Unknown decoding error")
            }
            
            throw NSError(
                domain: "AllTime",
                code: 1002,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to decode event creation response: \(decodingError.localizedDescription)",
                    "rawResponse": responseString,
                    "underlyingError": decodingError
                ]
            )
        } catch {
            print("❌ APIService: Unexpected error decoding response: \(error)")
            throw error
        }
    }
    
    // MARK: - Daily AI Summary
    
    /// Get daily AI summary for a specific date
    /// - Parameters:
    ///   - date: Optional date. If nil, uses today.
    /// - Returns: DailyAISummaryResponse
    func getDailyAISummary(date: Date? = nil) async throws -> DailyAISummaryResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/ai/daily-summary")!
        
        // Add date parameter if provided
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            urlComponents.queryItems = [
                URLQueryItem(name: "date", value: formatter.string(from: date))
            ]
        }
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        print("🤖 APIService: ===== FETCHING DAILY AI SUMMARY =====")
        print("🤖 APIService: URL: \(url)")
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            print("🤖 APIService: Date: \(formatter.string(from: date))")
        } else {
            print("🤖 APIService: Date: Today (default)")
        }
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🤖 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                // Don't use keyDecodingStrategy since DailyAISummaryResponse has explicit CodingKeys
                
                do {
                    let summary = try decoder.decode(DailyAISummaryResponse.self, from: data)
                    print("✅ APIService: Successfully decoded daily AI summary")
                    print("✅ APIService: Date: \(summary.date)")
                    print("✅ APIService: Total events: \(summary.totalEvents)")
                    print("✅ APIService: Key highlights: \(summary.keyHighlights.count)")
                    print("✅ APIService: Risks/conflicts: \(summary.risksOrConflicts.count)")
                    print("✅ APIService: Suggestions: \(summary.suggestions.count)")
                    return summary
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode DailyAISummaryResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode daily summary response: \(decodingError.localizedDescription)",
                            "rawResponse": responseString,
                            "underlyingError": decodingError
                        ]
                    )
                }
                
            case 401:
                print("❌ APIService: Unauthorized - invalid or expired token")
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            case 500:
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorData["message"] as? String {
                    print("❌ APIService: Server error: \(message)")
                    throw NSError(
                        domain: "AllTime",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Server error: \(message)"]
                    )
                }
                print("❌ APIService: Server error (500) - failed to generate summary")
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate summary"]
                )
                
            default:
                print("❌ APIService: Unexpected status code: \(httpResponse.statusCode)")
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Daily Summary API (Primary Endpoint)

    /// Get enhanced daily summary from /api/v1/daily-summary endpoint
    /// This is the primary endpoint for the DailySummaryView
    /// - Parameter date: Optional date. If nil, defaults to today.
    /// - Returns: DailySummary with all fields
    func getEnhancedDailySummary(date: Date? = nil) async throws -> DailySummary {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }

        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/daily-summary")!

        // Add date parameter if provided
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            urlComponents.queryItems = [
                URLQueryItem(name: "date", value: formatter.string(from: date))
            ]
        }

        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout

        print("📊 APIService: ===== FETCHING DAILY SUMMARY =====")
        print("📊 APIService: URL: \(url)")
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            print("📊 APIService: Date: \(formatter.string(from: date))")
        } else {
            print("📊 APIService: Date: Today (default)")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📊 APIService: Response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()

                do {
                    let summary = try decoder.decode(DailySummary.self, from: data)
                    print("✅ APIService: Successfully decoded daily summary")
                    print("✅ APIService: Day summary items: \(summary.daySummary.count)")
                    print("✅ APIService: Health summary items: \(summary.healthSummary.count)")
                    print("✅ APIService: Focus recommendations: \(summary.focusRecommendations.count)")
                    print("✅ APIService: Alerts: \(summary.alerts.count)")
                    if let suggestions = summary.healthBasedSuggestions {
                        print("✅ APIService: Health suggestions: \(suggestions.count)")
                    }
                    if let breaks = summary.breakRecommendations {
                        print("✅ APIService: Has break recommendations: true")
                        if let suggestedBreaks = breaks.suggestedBreaks {
                            print("✅ APIService: Suggested breaks: \(suggestedBreaks.count)")
                        }
                    }
                    return summary
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode DailySummary: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString.prefix(500))...")

                    // Log detailed decoding error
                    switch decodingError {
                    case .keyNotFound(let key, let context):
                        print("❌ APIService: Missing key '\(key.stringValue)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .typeMismatch(let type, let context):
                        print("❌ APIService: Type mismatch for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .valueNotFound(let type, let context):
                        print("❌ APIService: Value not found for type '\(type)' at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    case .dataCorrupted(let context):
                        print("❌ APIService: Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
                    @unknown default:
                        print("❌ APIService: Unknown decoding error")
                    }

                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode daily summary: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }

            case 401:
                print("❌ APIService: Unauthorized - invalid or expired token")
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )

            case 500:
                // Try to parse error message
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = errorData["message"] as? String {
                    print("❌ APIService: Server error: \(message)")
                    throw NSError(
                        domain: "AllTime",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Server error: \(message)"]
                    )
                }
                print("❌ APIService: Server error (500)")
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to generate summary. Please try again."]
                )

            default:
                print("❌ APIService: Unexpected status code: \(httpResponse.statusCode)")
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Unknown error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Food Recommendations API

    /// Get food recommendations near user's location
    /// - Parameters:
    ///   - radiusKm: Search radius in kilometers (default 1.5)
    ///   - category: "all", "healthy", or "regular"
    ///   - maxResults: Maximum results per category
    ///   - latitude: User's latitude (optional, uses default if not provided)
    ///   - longitude: User's longitude (optional, uses default if not provided)
    /// - Returns: FoodRecommendationsResponse
    func getFoodRecommendations(radiusMiles: Double = 1.5, category: String = "all", maxResults: Int = 15, latitude: Double? = nil, longitude: Double? = nil) async throws -> FoodRecommendationsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }

        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/recommendations/food")!

        // Build query items - latitude, longitude, and radius_miles are REQUIRED for proper results
        var queryItems = [
            URLQueryItem(name: "category", value: category),
            URLQueryItem(name: "max_results", value: String(maxResults))
        ]

        // Add radius_miles (required by backend)
        queryItems.append(URLQueryItem(name: "radius_miles", value: String(radiusMiles)))

        // Add location - REQUIRED for food recommendations to work properly
        if let lat = latitude, let lon = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: String(lat)))
            queryItems.append(URLQueryItem(name: "longitude", value: String(lon)))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout

        print("🍽️ APIService: ===== FETCHING FOOD RECOMMENDATIONS =====")
        print("🍽️ APIService: URL: \(url)")
        print("🍽️ APIService: Radius: \(radiusMiles) miles, Category: \(category)")
        if let lat = latitude, let lon = longitude {
            print("🍽️ APIService: Location: \(lat), \(lon)")
        } else {
            print("⚠️ APIService: WARNING - Location not provided! Results may be empty.")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🍽️ APIService: Response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                do {
                    let recommendations = try decoder.decode(FoodRecommendationsResponse.self, from: data)
                    print("✅ APIService: Successfully decoded food recommendations")
                    print("✅ APIService: Healthy options: \(recommendations.healthyOptions?.count ?? 0)")
                    print("✅ APIService: Regular options: \(recommendations.regularOptions?.count ?? 0)")
                    return recommendations
                } catch let decodingError {
                    print("❌ APIService: Failed to decode FoodRecommendationsResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString.prefix(500))...")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode food recommendations"]
                    )
                }

            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )

            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Walk Recommendations API

    /// Get walk route recommendations near user's location
    /// - Parameters:
    ///   - distanceMiles: Desired walking distance in miles
    ///   - difficulty: "easy", "moderate", or "challenging"
    ///   - latitude: User's latitude (optional, uses default if not provided)
    ///   - longitude: User's longitude (optional, uses default if not provided)
    /// - Returns: WalkRecommendationsResponse
    func getWalkRecommendations(distanceMiles: Double = 1.0, difficulty: String = "moderate", latitude: Double? = nil, longitude: Double? = nil) async throws -> WalkRecommendationsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }

        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/recommendations/walk")!
        var queryItems = [
            URLQueryItem(name: "distance_miles", value: String(distanceMiles)),
            URLQueryItem(name: "difficulty", value: difficulty)
        ]

        // Add location if available
        if let lat = latitude, let lon = longitude {
            queryItems.append(URLQueryItem(name: "latitude", value: String(lat)))
            queryItems.append(URLQueryItem(name: "longitude", value: String(lon)))
        }

        urlComponents.queryItems = queryItems

        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout

        print("🚶 APIService: ===== FETCHING WALK RECOMMENDATIONS =====")
        print("🚶 APIService: URL: \(url)")
        print("🚶 APIService: Distance: \(distanceMiles) miles, Difficulty: \(difficulty)")
        if let lat = latitude, let lon = longitude {
            print("🚶 APIService: Location: \(lat), \(lon)")
        } else {
            print("🚶 APIService: Location: Not provided (backend will use default)")
        }

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }

            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🚶 APIService: Response status: \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                do {
                    let recommendations = try decoder.decode(WalkRecommendationsResponse.self, from: data)
                    print("✅ APIService: Successfully decoded walk recommendations")
                    print("✅ APIService: Routes found: \(recommendations.routes?.count ?? 0)")
                    return recommendations
                } catch let decodingError {
                    print("❌ APIService: Failed to decode WalkRecommendationsResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString.prefix(500))...")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to decode walk recommendations"]
                    )
                }

            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )

            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Enhanced Daily Intelligence (v1 API - Legacy)

    /// Fetch enhanced daily summary for a specific date (legacy endpoint)
    /// - Parameter date: Optional date. If nil, backend defaults to today.
    /// - Returns: EnhancedDailySummaryResponse
    func fetchDailySummary(date: Date? = nil) async throws -> EnhancedDailySummaryResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/summary/daily")!
        
        // Add date parameter only if provided
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            urlComponents.queryItems = [
                URLQueryItem(name: "date", value: formatter.string(from: date))
            ]
        }
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("🤖 APIService: ===== FETCHING ENHANCED DAILY SUMMARY (v1) =====")
        print("🤖 APIService: URL: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🤖 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                // Don't use keyDecodingStrategy - EnhancedDailySummaryResponse has explicit CodingKeys
                
                do {
                    let summary = try decoder.decode(EnhancedDailySummaryResponse.self, from: data)
                    print("✅ APIService: Successfully decoded enhanced daily summary")
                    print("✅ APIService: Date: \(summary.date)")
                    print("✅ APIService: Highlights: \(summary.keyHighlights.count)")
                    print("✅ APIService: Issues: \(summary.potentialIssues.count)")
                    print("✅ APIService: Suggestions: \(summary.suggestions.count)")
                    return summary
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode EnhancedDailySummaryResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode daily summary: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }
                
            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch timeline for a specific day
    /// - Parameter date: Optional date. If nil, backend defaults to today.
    /// - Returns: TimelineDayResponse
    func fetchDayTimeline(date: Date? = nil) async throws -> TimelineDayResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/timeline/day")!
        
        // Add date parameter only if provided
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            urlComponents.queryItems = [
                URLQueryItem(name: "date", value: formatter.string(from: date))
            ]
        }
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("📅 APIService: ===== FETCHING DAY TIMELINE (v1) =====")
        print("📅 APIService: URL: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("📅 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                // Don't use keyDecodingStrategy - TimelineDayResponse has explicit CodingKeys
                
                do {
                    let timeline = try decoder.decode(TimelineDayResponse.self, from: data)
                    print("✅ APIService: Successfully decoded timeline")
                    print("✅ APIService: Date: \(timeline.date)")
                    print("✅ APIService: Items: \(timeline.items.count)")
                    return timeline
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode TimelineDayResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode timeline: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }
                
            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch life wheel insights for a date range
    /// - Parameters:
    ///   - start: Optional start date. If nil, backend defaults to 7 days ago.
    ///   - end: Optional end date. If nil, backend defaults to today.
    /// - Returns: LifeWheelResponse
    func fetchLifeWheel(start: Date? = nil, end: Date? = nil) async throws -> LifeWheelResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/insights/life-wheel")!
        var queryItems: [URLQueryItem] = []
        
        // Add date parameters only if provided
        if let start = start {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: start)))
        }
        
        if let end = end {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: end)))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("🎯 APIService: ===== FETCHING LIFE WHEEL (v1) =====")
        print("🎯 APIService: URL: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("🎯 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                // Don't use keyDecodingStrategy - LifeWheelResponse has explicit CodingKeys
                
                do {
                    let lifeWheel = try decoder.decode(LifeWheelResponse.self, from: data)
                    print("✅ APIService: Successfully decoded life wheel")
                    print("✅ APIService: Date range: \(lifeWheel.startDate) to \(lifeWheel.endDate)")
                    print("✅ APIService: Contexts: \(lifeWheel.distribution.keys.count)")
                    return lifeWheel
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode LifeWheelResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode life wheel: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }
                
            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Health Insights API (v1)
    
    /// Submit daily health metrics to the backend
    /// - Parameter metrics: Single metric or array of metrics for batch upload
    /// - Returns: SubmitHealthMetricsResponse
    func submitDailyHealthMetrics(_ metrics: [DailyHealthMetrics]) async throws -> SubmitHealthMetricsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        let url = URL(string: "\(baseURL)/api/v1/health/daily")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Constants.API.timeout
        
        // Encode metrics (single object or array)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let body: Data
        if metrics.count == 1 {
            body = try encoder.encode(metrics[0])
        } else {
            body = try encoder.encode(metrics)
        }
        
        request.httpBody = body
        
        print("💚 APIService: ===== SUBMITTING HEALTH METRICS =====")
        print("💚 APIService: URL: \(url)")
        print("💚 APIService: Metrics count: \(metrics.count)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("💚 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200, 201:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let result = try decoder.decode(SubmitHealthMetricsResponse.self, from: data)
                    print("✅ APIService: Successfully submitted health metrics")
                    print("✅ APIService: Records upserted: \(result.recordsUpserted)")
                    return result
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode SubmitHealthMetricsResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode response: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }
                
            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch health insights for a date range
    /// - Parameters:
    ///   - startDate: Start date (optional, defaults to 7 days ago)
    ///   - endDate: End date (optional, defaults to today)
    /// - Returns: HealthInsightsResponse
    func fetchHealthInsights(startDate: Date? = nil, endDate: Date? = nil) async throws -> HealthInsightsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/health/insights")!
        var queryItems: [URLQueryItem] = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let startDate = startDate {
            queryItems.append(URLQueryItem(name: "start_date", value: formatter.string(from: startDate)))
        }
        
        if let endDate = endDate {
            queryItems.append(URLQueryItem(name: "end_date", value: formatter.string(from: endDate)))
        }
        
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("💚 APIService: ===== FETCHING HEALTH INSIGHTS =====")
        print("💚 APIService: URL: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("💚 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                // Don't use keyDecodingStrategy - HealthInsightsResponse has explicit CodingKeys
                
                do {
                    let insights = try decoder.decode(HealthInsightsResponse.self, from: data)
                    print("✅ APIService: Successfully decoded health insights")
                    print("✅ APIService: Requested date range: \(startDate.map { formatter.string(from: $0) } ?? "none") to \(endDate.map { formatter.string(from: $0) } ?? "none")")
                    print("✅ APIService: Response date range: \(insights.startDate) to \(insights.endDate)")
                    if let days = insights.days {
                        print("✅ APIService: Days field from backend: \(days)")
                        if days != insights.perDayMetrics.count {
                            print("⚠️ APIService: WARNING - Days field (\(days)) doesn't match per_day_metrics count (\(insights.perDayMetrics.count))")
                        }
                    }
                    print("✅ APIService: Per-day metrics count: \(insights.perDayMetrics.count)")
                    print("✅ APIService: First date in response: \(insights.perDayMetrics.first?.date ?? "none")")
                    print("✅ APIService: Last date in response: \(insights.perDayMetrics.last?.date ?? "none")")
                    print("✅ APIService: Insights count: \(insights.insights.count)")
                    
                    // Verify date range matches request
                    if let requestedStart = startDate, let requestedEnd = endDate {
                        let requestedStartStr = formatter.string(from: requestedStart)
                        let requestedEndStr = formatter.string(from: requestedEnd)
                        if insights.startDate != requestedStartStr || insights.endDate != requestedEndStr {
                            print("⚠️ APIService: WARNING - Response date range doesn't match request!")
                            print("⚠️ APIService: Expected: \(requestedStartStr) to \(requestedEndStr)")
                            print("⚠️ APIService: Received: \(insights.startDate) to \(insights.endDate)")
                        } else {
                            print("✅ APIService: Date range verification passed")
                        }
                    }
                    
                    return insights
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode HealthInsightsResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode health insights: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }
                
            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Fetch health insights for a single day
    /// - Parameter date: Date (optional, defaults to today)
    /// - Returns: HealthInsightsResponse
    func fetchDayHealthInsights(date: Date? = nil) async throws -> HealthInsightsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlComponents = URLComponents(string: "\(baseURL)/api/v1/health/insights/day")!
        
        if let date = date {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            urlComponents.queryItems = [
                URLQueryItem(name: "date", value: formatter.string(from: date))
            ]
        }
        
        guard let url = urlComponents.url else {
            throw NSError(
                domain: "AllTime",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("💚 APIService: ===== FETCHING DAY HEALTH INSIGHTS =====")
        print("💚 APIService: URL: \(url)")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(
                    domain: "AllTime",
                    code: 500,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                )
            }
            
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            print("💚 APIService: Response status: \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                // Don't use keyDecodingStrategy - HealthInsightsResponse has explicit CodingKeys
                
                do {
                    let insights = try decoder.decode(HealthInsightsResponse.self, from: data)
                    print("✅ APIService: Successfully decoded day health insights")
                    print("✅ APIService: Date: \(insights.startDate)")
                    return insights
                } catch let decodingError as DecodingError {
                    print("❌ APIService: ===== DECODING ERROR =====")
                    print("❌ APIService: Failed to decode HealthInsightsResponse: \(decodingError)")
                    print("❌ APIService: Response was: \(responseString)")
                    throw NSError(
                        domain: "AllTime",
                        code: 1002,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to decode day health insights: \(decodingError.localizedDescription)",
                            "rawResponse": responseString
                        ]
                    )
                }
                
            case 401:
                throw NSError(
                    domain: "AllTime",
                    code: 401,
                    userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
                )
                
            default:
                throw NSError(
                    domain: "AllTime",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
                )
            }
        } catch {
            print("❌ APIService: Network error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Reminders API
    
    /// Create a new reminder
    func createReminder(_ request: ReminderRequest) async throws -> Reminder {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        urlRequest.httpBody = try encoder.encode(request)
        
        print("🔔 APIService: Creating reminder: \(request.title ?? "untitled")")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 201:
            let reminder = try decoder.decode(Reminder.self, from: data)
            print("✅ APIService: Reminder created: \(reminder.id)")
            return reminder
        case 400, 401, 404, 500:
            if let errorData = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorData.message])
            }
            fallthrough
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    /// Get all reminders, optionally filtered by status
    func getReminders(status: ReminderStatus? = nil) async throws -> [Reminder] {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        var urlString = "\(baseURL)/api/v1/reminders"
        if let status = status {
            urlString += "?status=\(status.rawValue)"
        }
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Fetching reminders\(status != nil ? " (status: \(status!.rawValue))" : "")")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AllTime", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        let responseData = try decoder.decode(RemindersResponse.self, from: data)
        print("✅ APIService: Fetched \(responseData.reminders.count) reminders")
        return responseData.reminders
    }

    /// Get reminders in a date range
    func getRemindersInRange(startDate: Date, endDate: Date) async throws -> [Reminder] {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        let formatter = DateFormatter.reminderISO8601
        
        var components = URLComponents(string: "\(baseURL)/api/v1/reminders/range")
        components?.queryItems = [
            URLQueryItem(name: "start_date", value: formatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: formatter.string(from: endDate))
        ]
        
        guard let url = components?.url else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Fetching reminders in range: \(formatter.string(from: startDate)) to \(formatter.string(from: endDate))")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NSError(domain: "AllTime", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        let responseData = try decoder.decode(RemindersRangeResponse.self, from: data)
        print("✅ APIService: Fetched \(responseData.reminders.count) reminders in range")
        return responseData.reminders
    }

    /// Get reminder by ID
    func getReminder(id: Int64) async throws -> Reminder {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders/\(id)") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Fetching reminder: \(id)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let reminder = try decoder.decode(Reminder.self, from: data)
            print("✅ APIService: Fetched reminder: \(reminder.id)")
            return reminder
        case 404:
            throw NSError(domain: "AllTime", code: 404, userInfo: [NSLocalizedDescriptionKey: "Reminder not found"])
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    /// Update reminder
    func updateReminder(id: Int64, request: ReminderRequest) async throws -> Reminder {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders/\(id)") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "PUT"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        urlRequest.httpBody = try encoder.encode(request)
        
        print("🔔 APIService: Updating reminder: \(id)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let reminder = try decoder.decode(Reminder.self, from: data)
            print("✅ APIService: Updated reminder: \(reminder.id)")
            return reminder
        case 400, 404:
            if let errorData = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorData.message])
            }
            fallthrough
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    /// Complete reminder
    func completeReminder(id: Int64) async throws -> Reminder {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders/\(id)/complete") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Completing reminder: \(id)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let reminder = try decoder.decode(Reminder.self, from: data)
            print("✅ APIService: Completed reminder: \(reminder.id)")
            return reminder
        case 404:
            throw NSError(domain: "AllTime", code: 404, userInfo: [NSLocalizedDescriptionKey: "Reminder not found"])
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    /// Snooze reminder
    func snoozeReminder(id: Int64, until: Date) async throws -> Reminder {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders/\(id)/snooze") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        let formatter = DateFormatter.reminderISO8601
        let requestBody: [String: String] = [
            "snooze_until": formatter.string(from: until)
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔔 APIService: Snoozing reminder \(id) until \(formatter.string(from: until))")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let reminder = try decoder.decode(Reminder.self, from: data)
            print("✅ APIService: Snoozed reminder: \(reminder.id)")
            return reminder
        case 400, 404:
            if let errorData = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorData.message])
            }
            fallthrough
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    /// Delete reminder
    func deleteReminder(id: Int64) async throws {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders/\(id)") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Deleting reminder: \(id)")
        
        let (_, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        switch httpResponse.statusCode {
        case 200:
            print("✅ APIService: Deleted reminder: \(id)")
        case 404:
            throw NSError(domain: "AllTime", code: 404, userInfo: [NSLocalizedDescriptionKey: "Reminder not found"])
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }
    
    /// Get reminders for an event
    func getRemindersForEvent(eventId: Int64) async throws -> [Reminder] {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/reminders/event/\(eventId)") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Fetching reminders for event: \(eventId)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let responseData = try decoder.decode(EventRemindersResponse.self, from: data)
            print("✅ APIService: Fetched \(responseData.reminders.count) reminders for event \(eventId)")
            return responseData.reminders
        case 404:
            throw NSError(domain: "AllTime", code: 404, userInfo: [NSLocalizedDescriptionKey: "Event not found"])
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    /// Preview recurring instances
    func previewRecurringInstances(reminderId: Int64, startDate: Date, endDate: Date) async throws -> [Reminder] {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        let formatter = DateFormatter.reminderISO8601
        
        var components = URLComponents(string: "\(baseURL)/api/v1/reminders/\(reminderId)/preview")
        components?.queryItems = [
            URLQueryItem(name: "start_date", value: formatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: formatter.string(from: endDate))
        ]
        
        guard let url = components?.url else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        print("🔔 APIService: Previewing recurring instances for reminder \(reminderId)")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AllTime", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }

        // Don't use .iso8601 or .convertFromSnakeCase - Reminder model has custom decoder
        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let responseData = try decoder.decode(PreviewRecurringInstancesResponse.self, from: data)
            print("✅ APIService: Previewed \(responseData.instances.count) instances")
            return responseData.instances
        case 400, 404:
            if let errorData = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorData.message])
            }
            fallthrough
        default:
            throw NSError(domain: "AllTime", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"])
        }
    }

    // MARK: - Health Summary & AI Suggestions
    
    /// Get health summary (GET /api/v1/health/summary)
    /// Returns nil if 404 (no summary exists), throws error for other failures
    func getHealthSummary() async throws -> HealthSummaryResponse? {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/health/summary") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("🏥 APIService: ===== FETCHING HEALTH SUMMARY =====")
        print("🏥 APIService: URL: \(url)")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AllTime",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
            )
        }
        
        print("🏥 APIService: Response status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let summary = try decoder.decode(HealthSummaryResponse.self, from: data)
                print("✅ APIService: Successfully decoded health summary")
                return summary
            } catch {
                print("❌ APIService: Failed to decode health summary: \(error)")
                throw NSError(
                    domain: "AllTime",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode health summary: \(error.localizedDescription)"]
                )
            }
            
        case 404:
            print("ℹ️ APIService: No health summary found (404)")
            return nil
            
        case 401:
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
            )
            
        default:
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ APIService: Server error (code: \(httpResponse.statusCode)): \(responseString)")
            throw NSError(
                domain: "AllTime",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
            )
        }
    }
    
    /// Generate AI health suggestions (POST /api/v1/health/suggestions)
    /// UPDATED: Now uses Advanced AI Summary Engine
    /// - Parameters:
    ///   - timezone: Optional IANA timezone (e.g., "America/New_York"). Defaults to device timezone.
    /// - Note: start_date and end_date are no longer used - service automatically analyzes past 14 days + next 14 days
    /// This is a slow operation (5-10 seconds) - show loading indicator
    func generateHealthSuggestions(timezone: String? = nil) async throws -> GenerateSuggestionsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        // Use device timezone if not provided
        let tz = timezone ?? TimeZone.current.identifier
        
        // Build URL with timezone query parameter
        var components = URLComponents(string: "\(baseURL)/api/v1/health/suggestions")
        components?.queryItems = [URLQueryItem(name: "timezone", value: tz)]
        
        guard let url = components?.url else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30.0 // Longer timeout for AI generation
        
        // New API format: no request body needed, but send empty JSON for compatibility
        request.httpBody = "{}".data(using: .utf8)
        
        print("🤖 APIService: ===== GENERATING ADVANCED AI HEALTH SUGGESTIONS =====")
        print("🤖 APIService: URL: \(url)")
        print("🤖 APIService: Timezone: \(tz)")
        print("🤖 APIService: Analyzing past 14 days + next 14 days automatically")
        print("🤖 APIService: This may take 5-10 seconds...")
        
        let (data, response) = try await session.data(for: request)
        
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let result = try decoder.decode(GenerateSuggestionsResponse.self, from: data)
            print("✅ APIService: Successfully generated advanced health suggestions")
            
            // Log new fields if available
            if let advanced = result.advancedSummary {
                print("✅ APIService: Advanced summary available")
                print("   - This week: \(advanced.thisWeek.prefix(100))...")
                print("   - Next week: \(advanced.nextWeek.prefix(100))...")
            }
            
            if let patterns = result.patterns, !patterns.isEmpty {
                print("✅ APIService: Patterns detected: \(patterns.count)")
                for pattern in patterns.prefix(3) {
                    print("   - \(pattern)")
                }
            }
            
            if let eventAdvice = result.eventSpecificAdvice, !eventAdvice.isEmpty {
                print("✅ APIService: Event-specific advice: \(eventAdvice.count) items")
            }
            
            if let healthSuggestions = result.healthSuggestions, !healthSuggestions.isEmpty {
                print("✅ APIService: Health suggestions: \(healthSuggestions.count) items")
            }
            
            // Log legacy format if present
            if let legacySummary = result.summary {
                print("✅ APIService: Legacy format also available - suggestions count: \(legacySummary.suggestions.count)")
            }
            
            return result
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ APIService: Failed to decode suggestions response: \(error)")
            print("❌ APIService: Response: \(String(responseString.prefix(500)))")
            throw NSError(
                domain: "AllTime",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode suggestions: \(error.localizedDescription)"]
            )
        }
    }
    
    // MARK: - Meeting Clash Detection
    
    /// Fetch meeting clashes (GET /api/v1/calendar/clashes)
    /// Detects overlapping calendar events and returns clash information grouped by date
    /// - Parameters:
    ///   - startDate: Start date for clash detection (defaults to today)
    ///   - endDate: End date for clash detection (defaults to today + 7 days)
    ///   - timezone: Optional IANA timezone (e.g., "America/New_York"). Defaults to device timezone.
    func fetchMeetingClashes(startDate: Date? = nil, endDate: Date? = nil, timezone: String? = nil) async throws -> ClashResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        // Default to today + 7 days if not provided
        let calendar = Calendar.current
        let start = startDate ?? Date()
        let end = endDate ?? calendar.date(byAdding: .day, value: 7, to: start) ?? start
        
        // Use device timezone if not provided
        let tz = timezone ?? TimeZone.current.identifier
        
        // Format dates as ISO 8601 (YYYY-MM-DD)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        
        let startString = dateFormatter.string(from: start)
        let endString = dateFormatter.string(from: end)
        
        // Build URL with query parameters
        var components = URLComponents(string: "\(baseURL)/api/v1/calendar/clashes")
        components?.queryItems = [
            URLQueryItem(name: "start", value: startString),
            URLQueryItem(name: "end", value: endString),
            URLQueryItem(name: "timezone", value: tz)
        ]
        
        guard let url = components?.url else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("📅 APIService: ===== FETCHING MEETING CLASHES =====")
        print("📅 APIService: URL: \(url)")
        print("📅 APIService: Date range: \(startString) to \(endString)")
        print("📅 APIService: Timezone: \(tz)")
        
        let (data, response) = try await session.data(for: request)
        
        try await validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let result = try decoder.decode(ClashResponse.self, from: data)
            print("✅ APIService: Successfully fetched meeting clashes")
            print("✅ APIService: Total clashes: \(result.totalClashes)")
            
            // Log clash details
            for (date, clashes) in result.clashesByDate {
                print("📅 APIService: \(date): \(clashes.count) clash(es)")
                for clash in clashes.prefix(3) {
                    print("   ⚠️ \(clash.eventA.title) overlaps with \(clash.eventB.title) by \(clash.overlapMinutes) min (severity: \(clash.severity))")
                }
            }
            
            return result
        } catch {
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ APIService: Failed to decode clashes response: \(error)")
            print("❌ APIService: Response: \(String(responseString.prefix(500)))")
            throw NSError(
                domain: "AllTime",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode clashes: \(error.localizedDescription)"]
            )
        }
    }
    
    /// Get user health goals (GET /api/v1/health/goals)
    func getHealthGoals() async throws -> UserHealthGoals {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/health/goals") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = Constants.API.timeout
        
        print("🎯 APIService: ===== FETCHING HEALTH GOALS =====")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AllTime",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
            )
        }
        
        print("🎯 APIService: Response status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                let goals = try decoder.decode(UserHealthGoals.self, from: data)
                print("✅ APIService: Successfully decoded health goals")
                return goals
            } catch {
                print("❌ APIService: Failed to decode health goals: \(error)")
                throw NSError(
                    domain: "AllTime",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode health goals: \(error.localizedDescription)"]
                )
            }
            
        case 401:
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
            )
            
        default:
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ APIService: Server error (code: \(httpResponse.statusCode)): \(responseString)")
            throw NSError(
                domain: "AllTime",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
            )
        }
    }
    
    /// Save user health goals (POST /api/v1/health/goals)
    func saveHealthGoals(_ request: SaveGoalsRequest) async throws -> SaveGoalsResponse {
        guard let token = accessToken else {
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication required. Please sign in again."]
            )
        }
        
        guard let url = URL(string: "\(baseURL)/api/v1/health/goals") else {
            throw NSError(domain: "AllTime", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.timeoutInterval = Constants.API.timeout
        
        // Note: SaveGoalsRequest has CodingKeys that explicitly define snake_case,
        // so we don't need convertToSnakeCase, but it won't hurt since CodingKeys take precedence
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestBody = try encoder.encode(request)
        urlRequest.httpBody = requestBody
        
        // Log the request body for debugging
        if let requestBodyString = String(data: requestBody, encoding: .utf8) {
            print("💾 APIService: ===== SAVING HEALTH GOALS =====")
            print("💾 APIService: Request URL: \(url)")
            print("💾 APIService: Request Body JSON: \(requestBodyString)")
            print("💾 APIService: Request values being sent:")
            print("   - sleep_hours: \(request.sleepHours?.description ?? "nil")")
            print("   - active_energy_burned: \(request.activeEnergyBurned?.description ?? "nil")")
            print("   - active_minutes: \(request.activeMinutes?.description ?? "nil")")
            print("   - steps: \(request.steps?.description ?? "nil")")
            print("   - resting_heart_rate: \(request.restingHeartRate?.description ?? "nil")")
            print("   - hrv: \(request.hrv?.description ?? "nil")")
        } else {
            print("❌ APIService: Failed to convert request body to string")
        }
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "AllTime",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
            )
        }
        
        print("💾 APIService: Response status: \(httpResponse.statusCode)")
        
        switch httpResponse.statusCode {
        case 200, 201:
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            do {
                // Log response body for debugging
                if let responseString = String(data: data, encoding: .utf8) {
                    print("💾 APIService: Response body: \(responseString)")
                }
                
                let result = try decoder.decode(SaveGoalsResponse.self, from: data)
                print("✅ APIService: Successfully saved health goals")
                print("✅ APIService: Saved goals:")
                print("   - sleep_hours: \(result.goals.sleepHours?.description ?? "nil")")
                print("   - active_energy_burned: \(result.goals.activeEnergyBurned?.description ?? "nil")")
                print("   - active_minutes: \(result.goals.activeMinutes?.description ?? "nil")")
                print("   - steps: \(result.goals.steps?.description ?? "nil")")
                print("   - resting_heart_rate: \(result.goals.restingHeartRate?.description ?? "nil")")
                print("   - hrv: \(result.goals.hrv?.description ?? "nil")")
                return result
            } catch {
                print("❌ APIService: Failed to decode save goals response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ APIService: Response body was: \(responseString)")
                }
                throw NSError(
                    domain: "AllTime",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode response: \(error.localizedDescription)"]
                )
            }
            
        case 401:
            throw NSError(
                domain: "AllTime",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please sign in again."]
            )
            
        default:
            let responseString = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ APIService: Server error (code: \(httpResponse.statusCode)): \(responseString)")
            throw NSError(
                domain: "AllTime",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server error (code: \(httpResponse.statusCode))"]
            )
        }
    }

    // MARK: - Intelligent Up Next

    /// Get intelligent "Up Next" suggestions based on calendar gaps and context.
    /// This analyzes your calendar to find free time slots and suggests contextual activities:
    /// - Lunch during 11:30 AM - 2:30 PM gaps
    /// - Gym/workout after 5 PM
    /// - Focus work during morning/afternoon gaps
    /// - Walking breaks for short gaps
    func getIntelligentUpNext(timezone: String = TimeZone.current.identifier) async throws -> UpNextItemsResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/today/upnext")!
        components.queryItems = [
            URLQueryItem(name: "timezone", value: timezone)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🎯 APIService: Fetching intelligent Up Next")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        // Debug: Log raw response to see date formats
        if let responseStr = String(data: data, encoding: .utf8) {
            print("🎯 APIService: Raw UpNext response (first 1500 chars):")
            print(String(responseStr.prefix(1500)))
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UpNextItemsResponse.self, from: data)
    }

    // MARK: - Tasks (Up Next)

    /// Quick add a task - just title, AI does the rest
    func quickAddTask(title: String, source: String = "quick_add", deadline: Date? = nil) async throws -> UserTask {
        let url = URL(string: "\(baseURL)/api/v1/tasks/quick")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Determine deadline type based on deadline
        let deadlineType: TaskDeadlineType? = deadline != nil ? .specificTime : nil
        let body = QuickAddRequest(title: title, source: source, deadline: deadline, deadlineType: deadlineType)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        print("🔵 APIService: Quick adding task: \(title), deadline: \(deadline?.description ?? "none")")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UserTask.self, from: data)
    }

    /// Flexible date decoder that handles multiple date formats from the backend
    private func flexibleDateDecoder(_ decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()

        // First, try to decode as an array (Jackson's default LocalDateTime serialization)
        // Format: [year, month, day, hour, minute, second?, nanosecond?]
        if let dateArray = try? container.decode([Int].self) {
            var components = DateComponents()
            components.timeZone = TimeZone.current

            if dateArray.count >= 3 {
                components.year = dateArray[0]
                components.month = dateArray[1]
                components.day = dateArray[2]
            }
            if dateArray.count >= 4 {
                components.hour = dateArray[3]
            }
            if dateArray.count >= 5 {
                components.minute = dateArray[4]
            }
            if dateArray.count >= 6 {
                components.second = dateArray[5]
            }
            if dateArray.count >= 7 {
                // Nanoseconds - convert to nanoseconds for DateComponents
                components.nanosecond = dateArray[6]
            }

            if let date = Calendar.current.date(from: components) {
                return date
            }
        }

        // Try to decode as a String
        guard let dateString = try? container.decode(String.self) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date is neither array nor string format")
        }

        // Try ISO8601 with fractional seconds and timezone
        let iso8601FormatterWithFractional = ISO8601DateFormatter()
        iso8601FormatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso8601FormatterWithFractional.date(from: dateString) {
            return date
        }

        // Try ISO8601 without fractional seconds
        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]
        if let date = iso8601Formatter.date(from: dateString) {
            return date
        }

        // Try without timezone (backend often returns this format)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
    }

    /// Create a task with full details
    func createTask(_ taskRequest: TaskRequest) async throws -> UserTask {
        let url = URL(string: "\(baseURL)/api/v1/tasks")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(taskRequest)

        print("🔵 APIService: Creating task: \(taskRequest.title)")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UserTask.self, from: data)
    }

    /// Update a task
    func updateTask(id: Int64, _ taskRequest: TaskRequest) async throws -> UserTask {
        let url = URL(string: "\(baseURL)/api/v1/tasks/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(taskRequest)

        print("🔵 APIService: Updating task \(id)")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UserTask.self, from: data)
    }

    /// Delete a task
    func deleteTask(id: Int64) async throws {
        let url = URL(string: "\(baseURL)/api/v1/tasks/\(id)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Deleting task \(id)")
        let (_, response) = try await session.data(for: request)
        try await validateResponse(response, data: Data())
    }

    /// Mark task as completed
    func completeTask(id: Int64, actualDurationMinutes: Int? = nil) async throws -> UserTask {
        let url = URL(string: "\(baseURL)/api/v1/tasks/\(id)/complete")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = CompleteTaskRequest(actualDurationMinutes: actualDurationMinutes)
        request.httpBody = try JSONEncoder().encode(body)

        print("🔵 APIService: Completing task \(id)")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UserTask.self, from: data)
    }

    /// Get today's tasks for "Up Next" section
    func getTodaysTasks(timezone: String = TimeZone.current.identifier) async throws -> UpNextResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/tasks/today")!
        components.queryItems = [
            URLQueryItem(name: "timezone", value: timezone)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching today's tasks")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UpNextResponse.self, from: data)
    }

    /// Get pending tasks
    func getPendingTasks() async throws -> [UserTask] {
        let url = URL(string: "\(baseURL)/api/v1/tasks/pending")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching pending tasks")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode([UserTask].self, from: data)
    }

    /// Get overdue tasks
    func getOverdueTasks() async throws -> [UserTask] {
        let url = URL(string: "\(baseURL)/api/v1/tasks/overdue")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching overdue tasks")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode([UserTask].self, from: data)
    }

    /// Auto-schedule pending tasks
    func autoScheduleTasks(date: Date = Date(), timezone: String = TimeZone.current.identifier) async throws -> ScheduleResponse {
        let url = URL(string: "\(baseURL)/api/v1/tasks/schedule")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let body = ScheduleTasksRequest(date: dateString, timezone: timezone)
        request.httpBody = try JSONEncoder().encode(body)

        print("🔵 APIService: Auto-scheduling tasks for \(dateString)")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(ScheduleResponse.self, from: data)
    }

    /// Get AI scheduling suggestion for a task
    func suggestTaskSchedule(taskId: Int64, date: Date = Date(), timezone: String = TimeZone.current.identifier) async throws -> UserTask {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        var components = URLComponents(string: "\(baseURL)/api/v1/tasks/\(taskId)/suggest")!
        components.queryItems = [
            URLQueryItem(name: "date", value: dateString),
            URLQueryItem(name: "timezone", value: timezone)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Getting schedule suggestion for task \(taskId)")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UserTask.self, from: data)
    }

    // MARK: - Today Overview API (Tiles)

    /// Fetch today overview for tile previews
    func fetchTodayOverview(timezone: String = TimeZone.current.identifier) async throws -> TodayOverviewResponse {
        var components = URLComponents(string: "\(baseURL)/api/v1/today/overview")!
        components.queryItems = [
            URLQueryItem(name: "timezone", value: timezone)
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching today overview")
        let (data, response) = try await session.data(for: request)

        // Log response for debugging
        if let responseString = String(data: data, encoding: .utf8) {
            print("🔵 APIService: Overview response: \(responseString.prefix(500))...")
        }

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(TodayOverviewResponse.self, from: data)
    }

    // MARK: - Task Convenience Methods (for ToDoDetailView)

    /// Fetch today's tasks as a simple array
    func fetchTodaysTasks(timezone: String = TimeZone.current.identifier) async throws -> [UserTask] {
        let response = try await getTodaysTasks(timezone: timezone)
        return response.tasks
    }

    /// Shared singleton instance for convenience
    static let shared = APIService()

    /// Update task status (PENDING, IN_PROGRESS, COMPLETED, etc.)
    func updateTaskStatus(taskId: Int, status: String) async throws -> UserTask {
        let url = URL(string: "\(baseURL)/api/v1/tasks/\(taskId)/status")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["status": status]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("🔵 APIService: Updating task \(taskId) status to \(status)")
        let (data, response) = try await session.data(for: request)
        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom(flexibleDateDecoder)
        return try decoder.decode(UserTask.self, from: data)
    }

    /// Delete a task (convenience overload with Int)
    func deleteTask(taskId: Int) async throws {
        try await deleteTask(id: Int64(taskId))
    }

    // MARK: - Predictions API

    /// Get all predictions for today
    func getTodayPredictions() async throws -> PredictionsResponse {
        let url = URL(string: "\(baseURL)/api/v1/predictions/today")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching today's predictions")
        let (data, response) = try await session.data(for: request)

        if let responseString = String(data: data, encoding: .utf8) {
            print("🔵 APIService: Predictions response: \(responseString.prefix(500))...")
        }

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(PredictionsResponse.self, from: data)
    }

    /// Get all predictions for a specific date
    func getPredictions(date: Date) async throws -> PredictionsResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let url = URL(string: "\(baseURL)/api/v1/predictions/\(dateString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching predictions for \(dateString)")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(PredictionsResponse.self, from: data)
    }

    /// Get travel predictions for today
    func getTodayTravelPredictions() async throws -> TravelPredictionsResponse {
        let url = URL(string: "\(baseURL)/api/v1/predictions/travel/today")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching today's travel predictions")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(TravelPredictionsResponse.self, from: data)
    }

    /// Get travel predictions for a specific date
    func getTravelPredictions(date: Date) async throws -> TravelPredictionsResponse {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let url = URL(string: "\(baseURL)/api/v1/predictions/travel/\(dateString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching travel predictions for \(dateString)")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(TravelPredictionsResponse.self, from: data)
    }

    /// Get capacity prediction for today
    func getTodayCapacity() async throws -> CapacityPrediction {
        let url = URL(string: "\(baseURL)/api/v1/predictions/capacity/today")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching today's capacity")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(CapacityPrediction.self, from: data)
    }

    /// Get capacity prediction for a specific date
    func getCapacityPrediction(date: Date) async throws -> CapacityPrediction {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        let url = URL(string: "\(baseURL)/api/v1/predictions/capacity/\(dateString)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching capacity for \(dateString)")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(CapacityPrediction.self, from: data)
    }

    /// Get capacity predictions for a week
    func getWeekCapacity(startDate: Date? = nil) async throws -> WeekCapacityResponse {
        var urlString = "\(baseURL)/api/v1/predictions/capacity/week"

        if let start = startDate {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: start)
            urlString += "?start=\(dateString)"
        }

        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching week capacity")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(WeekCapacityResponse.self, from: data)
    }

    /// Get detected event patterns
    func getEventPatterns() async throws -> PatternsResponse {
        let url = URL(string: "\(baseURL)/api/v1/predictions/patterns")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")

        print("🔵 APIService: Fetching event patterns")
        let (data, response) = try await session.data(for: request)

        try await validateResponse(response, data: data)

        let decoder = JSONDecoder()
        return try decoder.decode(PatternsResponse.self, from: data)
    }
}
