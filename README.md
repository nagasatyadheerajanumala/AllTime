# AllTime iOS App

A comprehensive SwiftUI-based iOS calendar application that aggregates events from Google, Outlook, and Apple calendars with AI-powered daily summaries.

## 📱 Features

### Core Functionality
- **Unified Calendar View**: Display events from all connected providers in a single, intuitive interface
- **Apple Sign-In Authentication**: Secure authentication using Apple ID with JWT token management
- **AI Daily Summaries**: Get personalized insights about your schedule and upcoming events
- **Multi-Provider Support**: Connect Google Calendar, Microsoft Outlook, and Apple Calendar
- **Smart Notifications**: Configurable push notifications for events and daily summaries
- **Event Management**: View detailed event information with location, time, and provider details

### User Experience
- **Modern SwiftUI Interface**: Clean, intuitive design following iOS design guidelines
- **MVVM Architecture**: Well-structured codebase with separation of concerns
- **Real-time Sync**: Automatic synchronization with backend services
- **Offline Support**: Cached data for offline viewing
- **Accessibility**: Full VoiceOver and accessibility support

## 🏗️ Architecture

### Project Structure
```
AllTime/
├── Models/
│   ├── User.swift
│   ├── Event.swift
│   └── AuthResponse.swift
├── Views/
│   ├── SignInView.swift
│   ├── MainTabView.swift
│   ├── CalendarView.swift
│   ├── DailySummaryView.swift
│   ├── SettingsView.swift
│   ├── EventRowView.swift
│   ├── EventDetailView.swift
│   ├── NotificationSettingsView.swift
│   ├── PrivacySettingsView.swift
│   ├── AboutView.swift
│   └── ProviderLinkView.swift
├── ViewModels/
│   ├── CalendarViewModel.swift
│   ├── DailySummaryViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── AuthenticationService.swift
│   ├── APIService.swift
│   └── NotificationService.swift
├── Utils/
│   ├── Extensions.swift
│   └── Constants.swift
└── AllTimeApp.swift
```

### MVVM Pattern
- **Models**: Data structures for User, Event, Provider, and API responses
- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Business logic and state management
- **Services**: API communication and external service integration

## 🔧 Technical Implementation

### Dependencies
- **SwiftUI**: Modern declarative UI framework
- **Combine**: Reactive programming for data flow
- **AuthenticationServices**: Apple Sign-In integration
- **UserNotifications**: Push notification handling
- **Foundation**: Core iOS functionality

### Key Components

#### Authentication Service
- Handles Apple Sign-In flow
- Manages JWT token storage and refresh
- Provides authentication state to the app

#### API Service
- Communicates with Spring Boot backend
- Handles all HTTP requests and responses
- Manages error handling and retry logic

#### Calendar View Model
- Manages event data and calendar state
- Handles date selection and event filtering
- Coordinates with API service for data fetching

#### Notification Service
- Manages push notification permissions
- Schedules daily summary and event reminders
- Handles notification interactions

## 🚀 Getting Started

### Prerequisites
- Xcode 15.0+
- iOS 17.0+
- Apple Developer Account (for Apple Sign-In)

### Installation
1. Clone the repository
2. Open `AllTime.xcodeproj` in Xcode
3. Configure your Apple Developer Team
4. Update the bundle identifier if needed
5. Build and run the project

### Configuration
1. **Backend URL**: Update the base URL in `Constants.swift`
2. **Apple Sign-In**: Ensure entitlements are properly configured
3. **Push Notifications**: Configure notification capabilities in Xcode

## 📋 API Integration

The app integrates with a Spring Boot backend that provides:

### Authentication Endpoints
- `POST /auth/apple` - Apple Sign-In verification
- `POST /auth/google` - Google Calendar linking
- `POST /auth/microsoft` - Microsoft Outlook linking

### Data Endpoints
- `GET /events` - Fetch user events
- `POST /sync` - Trigger manual sync
- `GET /summary/{date}` - Get daily AI summary
- `GET /user/profile` - Get user profile

## 🎨 UI/UX Features

### Calendar Interface
- Monthly calendar grid with event indicators
- Today's events list with detailed information
- Event detail view with full information
- Provider badges for event source identification

### Daily Summary
- AI-generated daily insights
- Key insights with numbered list
- Date picker for historical summaries
- Refresh functionality for updated content

### Settings
- User profile management
- Provider connection management
- Notification preferences
- Privacy and security settings
- About and support information

## 🔔 Notification System

### Daily Summaries
- Configurable delivery time
- AI-generated content
- Smart scheduling

### Event Reminders
- 15-minute default reminder
- Customizable timing
- Location information included

### Permission Handling
- Graceful permission requests
- Settings redirect for denied permissions
- Test notification functionality

## 🛡️ Security & Privacy

### Data Protection
- JWT token-based authentication
- Secure token storage in Keychain
- Encrypted API communication
- No data sharing without consent

### Privacy Features
- Local data caching
- User-controlled data export
- Account deletion capability
- Transparent data usage

## 🧪 Testing

### Unit Tests
- ViewModel logic testing
- Service layer testing
- Model validation testing

### UI Tests
- Authentication flow testing
- Calendar interaction testing
- Settings configuration testing

## 📱 Device Support

### iOS Versions
- iOS 17.0+ (primary target)
- iOS 16.0+ (compatibility)

### Device Types
- iPhone (all sizes)
- iPad (with adaptive layout)
- Apple Watch (future consideration)

## 🔄 Future Enhancements

### Planned Features
- Apple Watch companion app
- Widget support for quick calendar access
- Advanced AI insights and recommendations
- Team calendar sharing
- Voice commands integration
- Dark mode optimization

### Performance Improvements
- Background sync optimization
- Image caching for event attachments
- Lazy loading for large event lists
- Memory usage optimization

## 📄 License

This project is proprietary software developed for AllTime. All rights reserved.

## 🤝 Contributing

This is a private project. For questions or issues, please contact the development team.

## 📞 Support

For technical support or feature requests, please contact:
- Email: support@alltime.app
- Documentation: [Internal Wiki]
- Issue Tracker: [Internal Jira]

---

**AllTime** - Your unified calendar experience, powered by AI.

