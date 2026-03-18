//
//  NetworkModels.swift
//  AllTime
//
//  Network (My Network) data models
//

import Foundation

// MARK: - Smart Social Card

struct SmartSocialCard: Codable, Identifiable {
    let id: String
    let type: String                           // "event_match" | "free_together" | "reconnect"
    let connectionUserId: Int64
    let connectionName: String?
    let connectionProfilePicture: String?
    let sharedInterests: [String]?
    let headline: String
    let subtitle: String?
    let actionLabel: String
    let actionType: String                     // "invite_to_event" | "create_and_invite" | "view_events"
    let eventId: Int64?
    let eventTitle: String?
    let eventStartTime: String?
    let eventEndTime: String?
    let eventLocation: String?
    let eventDescription: String?
    let mutualSlotStart: String?
    let mutualSlotEnd: String?
    let mutualSlotDate: String?
    let suggestedActivity: String?
    let score: Double
    let scoreReasons: [String]?

    var isEventMatch: Bool { type == "event_match" }
    var isFreeTogether: Bool { type == "free_together" }

    var displayName: String {
        connectionName ?? "Connection"
    }

    enum CodingKeys: String, CodingKey {
        case id, type, headline, subtitle, score
        case connectionUserId = "connection_user_id"
        case connectionName = "connection_name"
        case connectionProfilePicture = "connection_profile_picture"
        case sharedInterests = "shared_interests"
        case actionLabel = "action_label"
        case actionType = "action_type"
        case eventId = "event_id"
        case eventTitle = "event_title"
        case eventStartTime = "event_start_time"
        case eventEndTime = "event_end_time"
        case eventLocation = "event_location"
        case eventDescription = "event_description"
        case mutualSlotStart = "mutual_slot_start"
        case mutualSlotEnd = "mutual_slot_end"
        case mutualSlotDate = "mutual_slot_date"
        case suggestedActivity = "suggested_activity"
        case scoreReasons = "score_reasons"
    }
}

// MARK: - Network Connection

struct NetworkConnection: Codable, Identifiable {
    let connectionId: Int64
    let userId: Int64?
    let fullName: String?
    let email: String?
    let profilePictureUrl: String?
    let status: String
    let isRequester: Bool
    let sharedInterests: [String]?
    let connectedSince: String?
    let location: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?

    var id: Int64 { connectionId }

    var displayName: String {
        fullName ?? email ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id"
        case userId = "user_id"
        case fullName = "full_name"
        case email
        case profilePictureUrl = "profile_picture_url"
        case status
        case isRequester = "is_requester"
        case sharedInterests = "shared_interests"
        case connectedSince = "connected_since"
        case location, city, latitude, longitude
    }
}

struct NetworkStats: Codable {
    let connectionCount: Int
    let pendingRequestCount: Int

    enum CodingKeys: String, CodingKey {
        case connectionCount = "connection_count"
        case pendingRequestCount = "pending_request_count"
    }
}

struct NetworkSuggestion: Codable, Identifiable {
    let id: Int64
    let friendName: String?
    let friendProfilePictureUrl: String?
    let suggestionType: String?
    let title: String
    let body: String?
    let sharedInterests: [String]?
    let suggestedDate: String?
    let suggestedStartTime: String?
    let suggestedEndTime: String?
    let eventId: Int64?
    let status: String

    var isEventShare: Bool {
        suggestionType == "event_share"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case friendName = "friend_name"
        case friendProfilePictureUrl = "friend_profile_picture_url"
        case suggestionType = "suggestion_type"
        case title, body
        case sharedInterests = "shared_interests"
        case suggestedDate = "suggested_date"
        case suggestedStartTime = "suggested_start_time"
        case suggestedEndTime = "suggested_end_time"
        case eventId = "event_id"
        case status
    }
}

struct ConnectionFreeTime: Codable {
    let connectionUserId: Int64
    let connectionName: String?
    let date: String
    let freeSlots: [FreeSlot]
    let mutualFreeSlots: [FreeSlot]
    let busyBlocks: [BusyBlock]?

    enum CodingKeys: String, CodingKey {
        case connectionUserId = "connection_user_id"
        case connectionName = "connection_name"
        case date
        case freeSlots = "free_slots"
        case mutualFreeSlots = "mutual_free_slots"
        case busyBlocks = "busy_blocks"
    }
}

struct BusyBlock: Codable, Identifiable {
    let startTime: String
    let endTime: String
    let durationMinutes: Int

    var id: String { "\(startTime)-\(endTime)" }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
    }
}

struct FreeSlot: Codable, Identifiable {
    let startTime: String
    let endTime: String
    let durationMinutes: Int
    let score: Int

    var id: String { "\(startTime)-\(endTime)" }

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case durationMinutes = "duration_minutes"
        case score
    }
}

struct SendConnectionRequestResponse: Codable {
    let status: String
    let message: String
}

struct AcceptInviteResponse: Codable {
    let status: String
    let message: String
    let eventId: Int64?

    enum CodingKeys: String, CodingKey {
        case status, message
        case eventId = "event_id"
    }
}

struct EventInviteResponse: Codable {
    let success: Bool
    let message: String
    let invitedCount: Int
    let failedEmails: [String]?

    enum CodingKeys: String, CodingKey {
        case success, message
        case invitedCount = "invited_count"
        case failedEmails = "failed_emails"
    }
}

struct EventInvite: Codable, Identifiable {
    let id: Int64
    let eventId: Int64
    let inviterUserId: Int64
    let inviterName: String?
    let inviterProfilePicture: String?
    let eventTitle: String
    let eventStartTime: String?
    let eventEndTime: String?
    let eventLocation: String?
    let eventDescription: String?
    let sharedInterests: [String]?
    let status: String
    let message: String?
    let createdAt: String?
    let respondedAt: String?

    var displayInviterName: String {
        inviterName ?? "Someone"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case inviterUserId = "inviter_user_id"
        case inviterName = "inviter_name"
        case inviterProfilePicture = "inviter_profile_picture"
        case eventTitle = "event_title"
        case eventStartTime = "event_start_time"
        case eventEndTime = "event_end_time"
        case eventLocation = "event_location"
        case eventDescription = "event_description"
        case sharedInterests = "shared_interests"
        case status, message
        case createdAt = "created_at"
        case respondedAt = "responded_at"
    }
}

struct InterestBasedEvent: Codable, Identifiable {
    let eventId: Int64
    let title: String
    let description: String?
    let location: String?
    let startTime: String
    let endTime: String
    let matchingInterests: [String]
    let matchScore: Double
    let connectionIsFree: Bool
    let isOnline: Bool?
    let meetingLink: String?

    var id: Int64 { eventId }

    var isOnlineEvent: Bool {
        isOnline ?? false
    }

    enum CodingKeys: String, CodingKey {
        case eventId = "event_id"
        case title
        case description
        case location
        case startTime = "start_time"
        case endTime = "end_time"
        case matchingInterests = "matching_interests"
        case matchScore = "match_score"
        case connectionIsFree = "connection_is_free"
        case isOnline = "is_online"
        case meetingLink = "meeting_link"
    }
}

struct EventInterestMatch: Codable, Identifiable {
    let connectionId: Int64
    let userId: Int64
    let fullName: String?
    let email: String?
    let profilePictureUrl: String?
    let matchingInterests: [String]
    let matchScore: Double
    let isFreeAtEventTime: Bool

    var id: Int64 { connectionId }

    var displayName: String {
        fullName ?? email ?? "Unknown"
    }

    enum CodingKeys: String, CodingKey {
        case connectionId = "connection_id"
        case userId = "user_id"
        case fullName = "full_name"
        case email
        case profilePictureUrl = "profile_picture_url"
        case matchingInterests = "matching_interests"
        case matchScore = "match_score"
        case isFreeAtEventTime = "is_free_at_event_time"
    }
}
