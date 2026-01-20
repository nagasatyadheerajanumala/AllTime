import Foundation
import UIKit

// MARK: - Focus Time Service
@MainActor
class FocusTimeService {
    static let shared = FocusTimeService()

    private let baseURL = Constants.API.baseURL
    private let timeout: TimeInterval = Constants.API.timeout

    private var accessToken: String? {
        KeychainManager.shared.getAccessToken()
    }

    private init() {}

    /// Creates a URL from the given string, throwing an error if invalid
    private func makeURL(_ path: String) throws -> URL {
        guard let url = URL(string: path) else {
            throw FocusTimeError.networkError("Invalid URL: \(path)")
        }
        return url
    }

    /// Creates URLComponents from the given string, throwing an error if invalid
    private func makeURLComponents(_ path: String) throws -> URLComponents {
        guard let components = URLComponents(string: path) else {
            throw FocusTimeError.networkError("Invalid URL components: \(path)")
        }
        return components
    }

    // MARK: - Block Focus Time

    /// Blocks focus time on the user's calendar(s)
    func blockFocusTime(
        start: Date,
        end: Date,
        title: String? = "Focus Time",
        description: String? = nil,
        enableFocusMode: Bool = true,
        calendarProvider: String = "all"
    ) async throws -> BlockTimeResponse {
        guard let token = accessToken else {
            throw FocusTimeError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/focus/block-time")
        print("🎯 FocusTimeService: Blocking time from \(start) to \(end)")

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = BlockTimeRequest(
            start: start,
            end: end,
            title: title,
            description: description,
            calendarProvider: calendarProvider,
            enableFocusMode: enableFocusMode
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FocusTimeError.networkError("Invalid response")
        }

        print("🎯 FocusTimeService: Response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200..<300:
            let result = try JSONDecoder().decode(BlockTimeResponse.self, from: data)
            print("🎯 FocusTimeService: Block time response: success=\(result.success)")
            // Log calendar sync results to debug Google Calendar issues
            if let calendarEvents = result.calendarEvents {
                for event in calendarEvents {
                    if event.success {
                        print("✅ FocusTimeService: \(event.provider) Calendar - Event created: \(event.eventId ?? "no id")")
                    } else {
                        print("❌ FocusTimeService: \(event.provider) Calendar - FAILED: \(event.error ?? "unknown error")")
                    }
                }
            } else {
                print("⚠️ FocusTimeService: No calendar_events in response - event may only be local")
            }
            return result
        case 401:
            throw FocusTimeError.unauthorized
        case 400..<500:
            if let errorBody = String(data: data, encoding: .utf8) {
                print("🎯 FocusTimeService: Error response: \(errorBody)")
            }
            throw FocusTimeError.badRequest("Invalid request parameters")
        default:
            throw FocusTimeError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }

    // MARK: - Quick Block

    /// Immediately blocks the next N minutes starting from now
    func quickBlock(minutes: Int = 30, title: String? = "Focus Time") async throws -> BlockTimeResponse {
        guard let token = accessToken else {
            throw FocusTimeError.unauthorized
        }

        var components = try makeURLComponents("\(baseURL)/api/v1/focus/quick-block")
        var queryItems = [URLQueryItem(name: "minutes", value: String(minutes))]
        if let title = title {
            queryItems.append(URLQueryItem(name: "title", value: title))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw FocusTimeError.networkError("Invalid URL")
        }

        print("🎯 FocusTimeService: Quick block for \(minutes) minutes")

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FocusTimeError.networkError("Invalid response")
        }

        print("🎯 FocusTimeService: Quick block response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200..<300:
            let result = try JSONDecoder().decode(BlockTimeResponse.self, from: data)
            print("🎯 FocusTimeService: Quick block response: success=\(result.success)")
            // Log calendar sync results to debug Google Calendar issues
            if let calendarEvents = result.calendarEvents {
                for event in calendarEvents {
                    if event.success {
                        print("✅ FocusTimeService: \(event.provider) Calendar - Event created: \(event.eventId ?? "no id")")
                    } else {
                        print("❌ FocusTimeService: \(event.provider) Calendar - FAILED: \(event.error ?? "unknown error")")
                    }
                }
            } else {
                print("⚠️ FocusTimeService: No calendar_events in response - event may only be local")
            }
            return result
        case 401:
            throw FocusTimeError.unauthorized
        default:
            throw FocusTimeError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }

    // MARK: - Get Connected Calendars

    /// Returns the user's connected calendars
    func getConnectedCalendars() async throws -> ConnectedCalendarsResponse {
        guard let token = accessToken else {
            throw FocusTimeError.unauthorized
        }

        let url = try makeURL("\(baseURL)/api/v1/focus/calendars")

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw FocusTimeError.networkError("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return try JSONDecoder().decode(ConnectedCalendarsResponse.self, from: data)
        case 401:
            throw FocusTimeError.unauthorized
        default:
            throw FocusTimeError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }

    // MARK: - Focus Mode Shortcut

    /// Opens the iOS Shortcuts app to run the AllTime Focus shortcut
    func triggerFocusModeShortcut(shortcutUrl: String? = nil) {
        let urlString = shortcutUrl ?? "shortcuts://run-shortcut?name=AllTime%20Focus"
        guard let url = URL(string: urlString) else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            print("🎯 FocusTimeService: Cannot open shortcuts URL - app may not be installed")
        }
    }
}

// MARK: - Errors

enum FocusTimeError: Error, LocalizedError {
    case unauthorized
    case badRequest(String)
    case serverError(String)
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Please sign in to block focus time"
        case .badRequest(let message):
            return message
        case .serverError(let message):
            return message
        case .networkError(let message):
            return message
        }
    }
}
