import Foundation

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshExpiresIn: Int
    let user: User
    let profileCompleted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshExpiresIn = "refresh_expires_in"
        case user
        case profileCompleted = "profile_completed"
    }
}

struct AppleSignInRequest: Codable {
    let identityToken: String
    let email: String?
    
    // Backend expects camelCase according to API docs, but trying both
    enum CodingKeys: String, CodingKey {
        case identityToken = "identityToken"
        case email = "email"
    }
    
    // Alternative encoding for snake_case (if backend expects it)
    func toJSONDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["identityToken"] = identityToken
        if let email = email {
            dict["email"] = email
        }
        return dict
    }
}

struct FullName: Codable {
    let givenName: String?
    let familyName: String?
    
    enum CodingKeys: String, CodingKey {
        case givenName = "given_name"
        case familyName = "family_name"
    }
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshExpiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshExpiresIn = "refresh_expires_in"
    }
}

struct ProviderLinkRequest: Codable {
    let provider: String
    let authCode: String
    
    enum CodingKeys: String, CodingKey {
        case provider
        case authCode = "auth_code"
    }
}

struct APIError: Codable, Error {
    let message: String
    let code: String?
    let details: String?
    var userInfo: [String: Any]? = nil // For transient failures and additional metadata
    
    var localizedDescription: String {
        return message
    }
    
    // Custom initializer to support userInfo
    init(message: String, code: String? = nil, details: String? = nil, userInfo: [String: Any]? = nil) {
        self.message = message
        self.code = code
        self.details = details
        self.userInfo = userInfo
    }
    
    // Codable conformance - userInfo is not encoded/decoded (runtime only)
    enum CodingKeys: String, CodingKey {
        case message, code, details
    }
}

struct SetupProfileRequest: Codable {
    let fullName: String
    let email: String?
    let profilePictureUrl: String?
    let dateOfBirth: String?
    let gender: String?
    let location: String?
    let bio: String?
    let phoneNumber: String?
    
    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email
        case profilePictureUrl = "profile_picture_url"
        case dateOfBirth = "date_of_birth"
        case gender
        case location
        case bio
        case phoneNumber = "phone_number"
    }
}
