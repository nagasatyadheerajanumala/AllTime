import Foundation
import SwiftUI

struct Constants {
    // MARK: - API Configuration
    struct API {
        static let baseURL = "https://alltime-backend-756952284083.us-central1.run.app"
        static let timeout: TimeInterval = 30.0
    }
    
    // MARK: - OAuth Configuration
    struct OAuth {
        static let googleClientId = "756952284083-45ajqmld27ouvj0437me9tjftjitlnbq.apps.googleusercontent.com"
        static let googleRedirectUri = "\(API.baseURL)/connections/google/callback"
        static let googleScopes = "https://www.googleapis.com/auth/calendar https://www.googleapis.com/auth/userinfo.email"
        static let callbackScheme = "alltime"
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let accessToken = "access_token"
        static let refreshToken = "refresh_token"
        static let dailySummaryEnabled = "daily_summary_enabled"
        static let eventRemindersEnabled = "event_reminders_enabled"
        static let dailySummaryTime = "daily_summary_time"
        static let lastSyncDate = "last_sync_date"
    }
    
    // MARK: - Notification Identifiers
    struct NotificationIdentifiers {
        static let dailySummary = "daily-summary"
        static let eventReminder = "event-reminder"
        static let testNotification = "test-notification"
    }
    
    // MARK: - UI Constants
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let cardPadding: CGFloat = 16
        static let sectionSpacing: CGFloat = 20
        static let itemSpacing: CGFloat = 8
        
        // Animation durations
        static let shortAnimation: Double = 0.2
        static let mediumAnimation: Double = 0.3
        static let longAnimation: Double = 0.5
    }
    
    // MARK: - Calendar Constants
    struct Calendar {
        static let defaultEventReminderMinutes = 15
        static let maxEventsPerPage = 50
        static let defaultSyncInterval: TimeInterval = 300 // 5 minutes
    }
    
    // MARK: - Provider Configuration
    struct Providers {
        static let supportedProviders = ["google", "microsoft", "apple"]
        
        static func displayName(for provider: String) -> String {
            switch provider.lowercased() {
            case "google":
                return "Google Calendar"
            case "microsoft", "outlook":
                return "Microsoft Outlook"
            case "apple":
                return "Apple Calendar"
            default:
                return provider.capitalized
            }
        }
        
        static func iconName(for provider: String) -> String {
            switch provider.lowercased() {
            case "google":
                return "g.circle.fill"
            case "microsoft", "outlook":
                return "m.circle.fill"
            case "apple":
                return "applelogo"
            default:
                return "calendar"
            }
        }
        
        static func color(for provider: String) -> Color {
            switch provider.lowercased() {
            case "google":
                return .red
            case "microsoft", "outlook":
                return .blue
            case "apple":
                return .gray
            default:
                return .secondary
            }
        }
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let networkError = "Network connection error. Please check your internet connection."
        static let authenticationError = "Authentication failed. Please sign in again."
        static let serverError = "Server error. Please try again later."
        static let unknownError = "An unknown error occurred. Please try again."
        static let noEventsFound = "No events found for the selected date."
        static let noSummaryAvailable = "No summary available for the selected date."
    }
    
    // MARK: - Success Messages
    struct SuccessMessages {
        static let signInSuccess = "Successfully signed in!"
        static let providerLinked = "Provider linked successfully!"
        static let providerUnlinked = "Provider unlinked successfully!"
        static let eventsSynced = "Events synced successfully!"
        static let settingsSaved = "Settings saved successfully!"
    }
}
