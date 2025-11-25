import Foundation

// MARK: - Professional Events Response (GET /events)
// Matches the new structured API response format

struct EventsResponse: Codable {
    let timeRange: TimeRange?
    let events: [CalendarEvent]
    let summary: EventsSummary?
    let pagination: PaginationInfo?
    let metadata: ResponseMetadata?
    
    enum CodingKeys: String, CodingKey {
        case timeRange = "time_range"
        case events
        case summary
        case pagination
        case metadata
    }
    
    // Convenience computed properties for backward compatibility
    var totalEvents: Int {
        summary?.totalEvents ?? events.count
    }
    
    var eventsToday: Int {
        summary?.eventsToday ?? 0
    }
    
    var eventsThisWeek: Int {
        summary?.eventsThisWeek ?? 0
    }
}

// MARK: - Time Range

struct TimeRange: Codable {
    let start: String  // ISO 8601 UTC
    let end: String    // ISO 8601 UTC
    let periodType: String  // "day", "week", "month", "year", or "custom"
    let periodValue: Int?  // Can be null for some period types
    let timezone: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case start, end
        case periodType = "period_type"
        case periodValue = "period_value"
        case timezone, description
    }
    
    // Computed properties for date parsing
    var startDate: Date? {
        ISO8601DateFormatter().date(from: start)
    }
    
    var endDate: Date? {
        ISO8601DateFormatter().date(from: end)
    }
}

// MARK: - Events Summary

struct EventsSummary: Codable {
    let totalEvents: Int
    let eventsToday: Int
    let eventsThisWeek: Int
    let eventsThisMonth: Int
    let allDayEvents: Int
    let eventsBySource: [String: Int]
    let eventsByDay: [String: Int]
    
    enum CodingKeys: String, CodingKey {
        case totalEvents = "total_events"
        case eventsToday = "events_today"
        case eventsThisWeek = "events_this_week"
        case eventsThisMonth = "events_this_month"
        case allDayEvents = "all_day_events"
        case eventsBySource = "events_by_source"
        case eventsByDay = "events_by_day"
    }
}

// MARK: - Pagination Info

struct PaginationInfo: Codable {
    let page: Int?  // Optional - backend may not always send this
    let limit: Int?  // Optional - backend may not always send this
    let total: Int?  // Optional - backend may not always send this
    let totalPages: Int?
    
    enum CodingKeys: String, CodingKey {
        case page, limit, total
        case totalPages = "total_pages"
    }
    
    var hasNext: Bool {
        guard let totalPages = totalPages, let page = page else { return false }
        return page < totalPages
    }
    
    var hasPrevious: Bool {
        guard let page = page else { return false }
        return page > 1
    }
    
    // Convenience properties with defaults
    var pageNumber: Int {
        page ?? 1
    }
    
    var limitValue: Int {
        limit ?? 50
    }
    
    var totalCount: Int {
        total ?? 0
    }
}

// MARK: - Response Metadata

struct ResponseMetadata: Codable {
    let apiVersion: String?  // Optional - backend may not always send this
    let requestTimestamp: String?  // Optional - backend may not always send this
    let syncInfo: SyncInfo?  // Optional - backend may not always send this
    
    enum CodingKeys: String, CodingKey {
        case apiVersion = "api_version"
        case requestTimestamp = "request_timestamp"
        case syncInfo = "sync_info"
    }
    
    // Convenience properties for backward compatibility
    var syncStatus: String {
        syncInfo?.status ?? "unknown"
    }
    
    var lastSyncedAt: String? {
        syncInfo?.lastSyncedAt
    }
    
    var syncDurationMs: Int64? {
        syncInfo?.syncDurationMs
    }
    
    var lastSyncedDate: Date? {
        guard let lastSyncedAt = syncInfo?.lastSyncedAt else { return nil }
        return ISO8601DateFormatter().date(from: lastSyncedAt)
    }
}

struct SyncInfo: Codable {
    let status: String  // "synced", "syncing", "failed", or "not_synced"
    let lastSyncedAt: String?  // ISO 8601 UTC
    let syncDurationMs: Int64?
    
    enum CodingKeys: String, CodingKey {
        case status
        case lastSyncedAt = "last_synced_at"
        case syncDurationMs = "sync_duration_ms"
    }
}

// MARK: - Enhanced Sync Response (POST /sync)

struct SyncResponse: Codable {
    let status: String
    let message: String
    let userId: Int
    let eventsSynced: Int
    let diagnostics: SyncDiagnostics?
    
    enum CodingKeys: String, CodingKey {
        case status, message
        case userId = "user_id"
        case eventsSynced = "total_events_synced"
        case diagnostics
    }
}

struct SyncDiagnostics: Codable {
    let google: ProviderSyncDiagnostics?
    let microsoft: ProviderSyncDiagnostics?
}

struct ProviderSyncDiagnostics: Codable {
    let status: String  // "success" or "failed"
    let eventsSynced: Int?
    let calendarsProcessed: Int?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case eventsSynced = "events_synced"
        case calendarsProcessed = "calendars_processed"
        case error
    }
}

// MARK: - Legacy Support (for backward compatibility)

// Keep the old simple response for endpoints that still use it
struct SimpleEventsResponse: Codable {
    let events: [CalendarEvent]
    let totalCount: Int
    let page: Int
    let limit: Int
    
    enum CodingKeys: String, CodingKey {
        case events
        case totalCount = "total_count"
        case page, limit
    }
}

