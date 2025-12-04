import Foundation

// MARK: - Calendar Diagnostics Response

struct CalendarDiagnosticsResponse: Codable {
    let connections: [ConnectionDiagnostic]
}

struct ConnectionDiagnostic: Codable {
    let id: Int
    let provider: String
    let tokenStatus: String
    let expiresAt: String
    let minutesUntilExpiry: Int?
    let oauthCredentialsConfigured: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, provider
        case tokenStatus = "token_status"
        case expiresAt = "expires_at"
        case minutesUntilExpiry = "minutes_until_expiry"
        case oauthCredentialsConfigured = "oauth_credentials_configured"
    }
}

// MARK: - Sync Status Response

struct SyncStatusResponse: Codable {
    let lastSyncedAt: String?
    let syncInProgress: Bool
    let connections: [ConnectionSyncStatus]
    
    enum CodingKeys: String, CodingKey {
        case lastSyncedAt = "last_synced_at"
        case syncInProgress = "sync_in_progress"
        case connections
    }
}

struct ConnectionSyncStatus: Codable {
    let provider: String
    let status: String
    let lastSynced: String?
    
    enum CodingKeys: String, CodingKey {
        case provider, status
        case lastSynced = "last_synced"
    }
}

// MARK: - Summary Preferences Response

struct SummaryPreferencesResponse: Codable {
    let timePreference: String
    let includeWeather: Bool
    let includeTraffic: Bool
    
    enum CodingKeys: String, CodingKey {
        case timePreference = "time_preference"
        case includeWeather = "include_weather"
        case includeTraffic = "include_traffic"
    }
}


// MARK: - Connection Status

struct ConnectionStatus: Codable {
    let connected: Bool
    let externalUserId: String?
    let expiresAt: String?
    
    enum CodingKeys: String, CodingKey {
        case connected
        case externalUserId = "external_user_id"
        case expiresAt = "expires_at"
    }
}

// MARK: - Push Notification Status

struct PushNotificationStatus: Codable {
    let enabled: Bool
    let deviceTokenRegistered: Bool
    let apnsConfigured: Bool
    
    enum CodingKeys: String, CodingKey {
        case enabled
        case deviceTokenRegistered = "device_token_registered"
        case apnsConfigured = "apns_configured"
    }
}

// MARK: - Summary History

struct SummaryHistoryResponse: Codable {
    let message: String
    let userId: Int64
    let startDate: String
    let endDate: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case userId = "user_id"
        case startDate = "start_date"
        case endDate = "end_date"
    }
}

// MARK: - API Error Response

struct APIErrorResponse: Codable {
    let error: String
    let message: String
}

// MARK: - OAuth Start Response

struct OAuthStartResponse: Codable {
    let authorizationUrl: String

    enum CodingKeys: String, CodingKey {
        case authorizationUrl = "authorization_url"
    }
}

