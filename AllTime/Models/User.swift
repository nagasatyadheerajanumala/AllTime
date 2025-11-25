import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String?
    let fullName: String?
    let createdAt: String?  // Made optional - backend may not always return this
    let profilePictureUrl: String?
    let profileCompleted: Bool?
    let dateOfBirth: String?
    let gender: String?
    let location: String?
    let bio: String?
    let phoneNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case createdAt = "created_at"
        case profilePictureUrl = "profile_picture_url"
        case profileCompleted = "profile_completed"
        case dateOfBirth = "date_of_birth"
        case gender
        case location
        case bio
        case phoneNumber = "phone_number"
    }
}

// Connected Calendar from backend
struct ConnectedCalendar: Codable, Identifiable {
    let id: Int
    let provider: String
    let externalUserId: String
    let scope: String
    let expiresAt: String?
    let createdAt: String
    let email: String?  // Backend now returns email field directly
    
    enum CodingKeys: String, CodingKey {
        case id
        case provider
        case externalUserId = "external_user_id"
        case scope
        case expiresAt = "expires_at"
        case createdAt = "created_at"
        case email
    }
    
    // Compatibility properties - use email if available, otherwise fallback
    var displayEmail: String {
        // Backend returns email field directly
        if let email = email, !email.isEmpty {
            return email
        }
        // Fallback: If externalUserId looks like an email, use it directly
        if externalUserId.contains("@") && externalUserId.contains(".") {
            return externalUserId
        }
        // Otherwise, try to format it better or show a placeholder
        if externalUserId.contains("_") {
            return "\(provider.capitalized) Account"
        }
        // Last resort: use as-is
        return externalUserId
    }
    
    // Display name for UI (prioritizes email, falls back to formatted provider name)
    var displayName: String {
        // Use email if available
        if let email = email, !email.isEmpty {
            return email
        }
        // Fallback: If externalUserId looks like an email, use it directly
        if externalUserId.contains("@") && externalUserId.contains(".") {
            return externalUserId
        }
        // If it's a generic ID like "google_user_1", show provider name
        if externalUserId.lowercased().contains(provider.lowercased()) {
            return "\(provider.capitalized) Calendar"
        }
        // Otherwise, show the provider name
        return "\(provider.capitalized) Account"
    }
    
    var isActive: Bool { true }
    var lastSyncedAt: Date? { 
        // Use SyncScheduler's lastSyncTime if available, otherwise fallback to createdAt
        if let syncTime = SyncScheduler.shared.lastSyncTime {
            return syncTime
        }
        return ISO8601DateFormatter().date(from: createdAt)
    }
    var eventCount: Int? { nil } // Will be calculated by ViewModel
}

struct CalendarListResponse: Codable {
    let calendars: [ConnectedCalendar]
    let count: Int
}

// Legacy Provider model (for compatibility)
typealias Provider = ConnectedCalendar

struct DeleteCalendarResponse: Codable {
    let status: String
    let message: String
    let provider: String
}

struct ProvidersResponse: Codable {
    let providers: [ConnectedCalendar]
    let count: Int
    
    init(providers: [ConnectedCalendar], count: Int) {
        self.providers = providers
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let calendars = try container.decode([ConnectedCalendar].self, forKey: .calendars)
        self.count = try container.decode(Int.self, forKey: .count)
        self.providers = calendars
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providers, forKey: .calendars)
        try container.encode(count, forKey: .count)
    }
    
    enum CodingKeys: String, CodingKey {
        case calendars
        case count
    }
}
