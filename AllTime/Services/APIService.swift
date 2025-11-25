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
        
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
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
        
        if statusCode != 200 {
            print("🔄 APIService: Refresh failed with status: \(statusCode)")
        }
        
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(Provider.self, from: data)
    }
    
    // MARK: - User Profile
    func fetchUserProfile() async throws -> User {
        // Backend endpoint: GET /api/user/me (per frontend developer guide)
        let url = URL(string: "\(baseURL)/api/user/me")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
            
            try validateResponse(response, data: data)
            
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
        
        try validateResponse(response, data: data)
        
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
        
        try validateResponse(response, data: data)
        
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
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        // Note: EventsResponse uses explicit CodingKeys, so keyDecodingStrategy is not needed
        let decoder = JSONDecoder()
        return try decoder.decode(EventsResponse.self, from: data)
    }
    
    func syncEvents() async throws -> SyncResponse {
        let url = URL(string: "\(baseURL)/sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(DailySummary.self, from: data)
    }
    
    func fetchTodaySummary() async throws -> DailySummary {
        let url = URL(string: "\(baseURL)/api/summary/today")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(DailySummary.self, from: data)
    }
    
    func forceGenerateSummary() async throws -> DailySummary {
        let url = URL(string: "\(baseURL)/api/summary/send-now")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        return try JSONDecoder().decode(DailySummary.self, from: data)
    }
    
    func fetchSummaryPreferences() async throws -> SummaryPreferences {
        let url = URL(string: "\(baseURL)/api/summary/preferences")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
    }
    
    // MARK: - User Management
    func updateUserProfile(fullName: String, email: String?) async throws -> User {
        // Backend endpoint: PUT /user/profile (per API documentation)
        let url = URL(string: "\(baseURL)/user/profile")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        // Backend expects camelCase: fullName and email
        var body: [String: Any] = [
            "fullName": fullName
        ]
        if let email = email {
            body["email"] = email
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        // Decode and return updated user profile
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(User.self, from: data)
    }
    
    func fetchUserPreferences() async throws -> String {
        let url = URL(string: "\(baseURL)/api/user/preferences")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
    }
    
    // MARK: - OAuth Flows
    func getGoogleOAuthStartURL() async throws -> String {
        let url = URL(string: "\(baseURL)/connections/google/start")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        // Parse the response to get the OAuth URL
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauthURL = json["oauth_url"] as? String {
            return oauthURL
        } else {
            throw OAuthError.networkError("Invalid response format")
        }
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
        try validateResponse(response, data: data)
    }
    
    func getMicrosoftOAuthStartURL() async throws -> String {
        let url = URL(string: "\(baseURL)/connections/microsoft/start")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        // Parse the response to get the OAuth URL
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let oauthURL = json["oauth_url"] as? String {
            return oauthURL
        } else {
            throw OAuthError.networkError("Invalid response format")
        }
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
        try validateResponse(response, data: data)
    }
    
    // MARK: - Calendar Diagnostics
    
    func getCalendarDiagnostics() async throws -> CalendarDiagnosticsResponse {
        let url = URL(string: "\(baseURL)/calendars/diagnostics")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
    }
    
    func sendTestNotification() async throws {
        // Backend endpoint: POST /push/test (per API documentation)
        let url = URL(string: "\(baseURL)/push/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }
    
    func sendDailySummaryNotification() async throws {
        // Backend endpoint: POST /push/test (per API documentation)
        let url = URL(string: "\(baseURL)/push/test")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }
    
    func sendCalendarSyncNotification() async throws {
        let url = URL(string: "\(baseURL)/api/push/calendar-sync")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }
    
    func getPushNotificationStatus() async throws -> PushNotificationStatus {
        let url = URL(string: "\(baseURL)/api/push/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PushNotificationStatus.self, from: data)
    }
    
    func getGoogleConnectionStatus() async throws -> ConnectionStatus {
        let url = URL(string: "\(baseURL)/connections/google/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ConnectionStatus.self, from: data)
    }
    
    func getMicrosoftConnectionStatus() async throws -> ConnectionStatus {
        let url = URL(string: "\(baseURL)/connections/microsoft/status")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
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
        
        try validateResponse(response, data: data)
        
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
        
        print("🌐 APIService: Sending sync request...")
        let (data, response) = try await session.data(for: request)
        
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🌐 APIService: Sync response status: \(statusCode)")
        
        let responseString = String(data: data, encoding: .utf8) ?? "No response body"
        print("🌐 APIService: ===== RAW SYNC RESPONSE =====")
        print("🌐 APIService: \(responseString)")
        
        try validateResponse(response, data: data)
        
        // Use standard decoder - SyncResponse has explicit CodingKeys for field mapping
        // Note: When using explicit CodingKeys, keyDecodingStrategy is ignored
        let decoder = JSONDecoder()
        
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
        try validateResponse(response, data: data)
        
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
        try validateResponse(response, data: data)
        
        // If we get here, decode the response
        // Note: EventDetails uses explicit CodingKeys, so we don't need keyDecodingStrategy
        let decoder = JSONDecoder()
        return try decoder.decode(EventDetails.self, from: data)
    }
    
    // MARK: - Helper Methods
    private func validateResponse(_ response: URLResponse, data: Data? = nil) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ APIService: ===== VALIDATION ERROR =====")
            print("❌ APIService: Invalid response - not HTTPURLResponse")
            throw APIError(message: "Invalid response", code: nil, details: nil)
        }
        
        print("🌐 APIService: ===== RESPONSE VALIDATION =====")
        print("🌐 APIService: HTTP Status Code: \(httpResponse.statusCode)")
        print("🌐 APIService: Response Headers: \(httpResponse.allHeaderFields)")
        
        guard 200...299 ~= httpResponse.statusCode else {
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
                } else if let errorString = String(data: data, encoding: .utf8) {
                    // Fallback to plain string
                    print("❌ APIService: Backend Error Response (plain text): \(errorString)")
                    backendError = errorString
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
        
        try validateResponse(response, data: data)
        
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
    
    // MARK: - Enhanced Daily Intelligence (v1 API)
    
    /// Fetch enhanced daily summary for a specific date
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
                    print("✅ APIService: Date range: \(insights.startDate) to \(insights.endDate)")
                    print("✅ APIService: Days: \(insights.perDayMetrics.count)")
                    print("✅ APIService: Insights: \(insights.insights.count)")
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
}
