# AllTime iOS App - Complete API Flow Documentation

**Generated:** November 20, 2025  
**Project:** AllTime iOS App  
**Base URL:** `https://alltime-backend-756952284083.us-central1.run.app` (from `AllTime/Utils/Constants.swift`)

---

## Table of Contents

1. [API Service Overview](#api-service-overview)
2. [Authentication APIs](#authentication-apis)
3. [User Profile APIs](#user-profile-apis)
4. [Calendar & Events APIs](#calendar--events-apis)
5. [Health & Insights APIs](#health--insights-apis)
6. [Summary & AI APIs](#summary--ai-apis)
7. [OAuth & Provider APIs](#oauth--provider-apis)
8. [Push Notification APIs](#push-notification-apis)
9. [HealthKit Authorization Flow](#healthkit-authorization-flow)
10. [Call Graphs & Flowcharts](#call-graphs--flowcharts)
11. [HealthKit Authorization Status Checks](#healthkit-authorization-status-checks)

---

## API Service Overview

**File:** `AllTime/Services/APIService.swift`

**Base Configuration:**
- Base URL: `Constants.API.baseURL`
- Session: `URLSession.shared`
- Timeout: `Constants.API.timeout`
- Authentication: JWT Bearer token from `KeychainManager.shared.getAccessToken()`

**Standard Headers:**
- `Authorization: Bearer <token>` (for authenticated requests)
- `Content-Type: application/json` (for POST/PUT requests)
- `Accept: application/json` (for GET requests)

---

## Authentication APIs

### 1. Sign In with Apple

**File:** `AllTime/Services/APIService.swift`  
**Function:** `signInWithApple(identityToken:authorizationCode:userIdentifier:email:fullName:)`  
**Endpoint:** `POST /auth/apple`  
**Method:** POST

**Parameters:**
```swift
{
  "identityToken": String,      // Required - Apple ID token
  "email": String?,              // Optional - User email
  "authorizationCode": String?,  // Optional - Authorization code
  "userIdentifier": String,      // Required - Apple user ID
  "fullName": PersonNameComponents? // Optional - User's full name
}
```

**Headers:**
- `Content-Type: application/json`

**Response Model:** `AuthResponse`
- `accessToken: String`
- `refreshToken: String`
- `user: User`

**Consumed By:**
- `AuthenticationService.signInWithApple()`
- Triggered by: Sign In button in `SignInView`

**Triggers:**
- User taps "Sign in with Apple" button
- `SignInView` → `AuthenticationService.signInWithApple()`

---

### 2. Refresh Token

**File:** `AllTime/Services/APIService.swift`  
**Function:** `refreshToken(refreshToken:)`  
**Endpoint:** `POST /auth/refresh`  
**Method:** POST

**Parameters:**
```swift
{
  "refreshToken": String
}
```

**Headers:**
- `Content-Type: application/json`

**Response Model:** `RefreshTokenResponse`
- `accessToken: String`
- `refreshToken: String`

**Consumed By:**
- `AuthenticationService` (automatic token refresh)
- Triggered by: 401 responses or token expiration

---

### 3. Logout

**File:** `AllTime/Services/APIService.swift`  
**Function:** `logout()`  
**Endpoint:** `POST /auth/logout`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response:** Empty (200 OK)

**Consumed By:**
- `AuthenticationService.logout()`
- Triggered by: User taps "Sign Out" in Settings

---

### 4. Link Provider (Google/Microsoft)

**File:** `AllTime/Services/APIService.swift`  
**Function:** `linkProvider(provider:authCode:)`  
**Endpoint:** `POST /auth/{provider}` (where provider = "google" or "microsoft")  
**Method:** POST

**Parameters:**
```swift
{
  "provider": String,    // "google" or "microsoft"
  "authCode": String     // OAuth authorization code
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `Provider`
- `id: Int`
- `provider: String`
- `externalUserId: String`
- `displayName: String`

**Consumed By:**
- `OAuthManager` after OAuth flow completion
- Triggered by: User completes OAuth flow in `GoogleAuthManager` or `MicrosoftAuthManager`

---

## User Profile APIs

### 5. Fetch User Profile

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchUserProfile()`  
**Endpoint:** `GET /api/user/me`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `User`
- `id: Int64`
- `appleSub: String`
- `email: String?`
- `fullName: String?`
- `profileCompleted: Bool?`
- `profilePictureUrl: String?`
- `dateOfBirth: String?`
- `gender: String?`
- `location: String?`
- `bio: String?`
- `phoneNumber: String?`

**Consumed By:**
- `UserManager.fetchUserProfile()`
- `SettingsViewModel`
- Triggered by: App launch, profile view appears, after profile update

---

### 6. Setup Profile

**File:** `AllTime/Services/APIService.swift`  
**Function:** `setupProfile(fullName:email:profilePictureUrl:dateOfBirth:gender:location:bio:phoneNumber:)`  
**Endpoint:** `POST /api/user/profile/setup`  
**Method:** POST

**Parameters:**
```swift
{
  "full_name": String,
  "email": String?,
  "profile_picture_url": String?,
  "date_of_birth": String?,
  "gender": String?,
  "location": String?,
  "bio": String?,
  "phone_number": String?
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `User`

**Consumed By:**
- `ProfileSetupView` (on profile completion)
- Triggered by: User completes profile setup form

---

### 7. Update User Profile

**File:** `AllTime/Services/APIService.swift`  
**Function:** `updateUserProfile(fullName:email:preferences:profilePictureUrl:dateOfBirth:gender:location:bio:phoneNumber:)`  
**Endpoint:** `PUT /api/user/update`  
**Method:** PUT

**Parameters:** (All optional, only provided fields are sent)
```swift
{
  "full_name": String?,
  "email": String?,
  "preferences": String?,
  "profile_picture_url": String?,
  "date_of_birth": String?,
  "gender": String?,
  "location": String?,
  "bio": String?,
  "phone_number": String?
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `User`

**Consumed By:**
- `SettingsViewModel.updateProfile()`
- `ProfileDetailView`
- Triggered by: User saves profile changes in Settings

---

### 8. Update Profile Picture

**File:** `AllTime/Services/APIService.swift`  
**Function:** `updateProfilePicture(url:)`  
**Endpoint:** `POST /api/user/profile/picture`  
**Method:** POST

**Parameters:**
```swift
{
  "profile_picture_url": String
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `User`

**Consumed By:**
- `ProfileDetailView` (after image upload)
- Triggered by: User uploads new profile picture

---

## Calendar & Events APIs

### 9. Fetch Events

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchEvents(startDate:endDate:days:period:page:limit:autoSync:)`  
**Endpoint:** `GET /events`  
**Method:** GET

**Query Parameters:**
- `start`: ISO8601 date string (optional)
- `end`: ISO8601 date string (optional)
- `days`: Int (optional)
- `period`: String (optional)
- `page`: Int (default: 1)
- `limit`: Int (optional)
- `autoSync`: Bool (default: true)

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `EventsResponse`
- `events: [CalendarEvent]`
- `totalEvents: Int`
- `timeRange: TimeRange?`
- `summary: EventsSummary?`

**Consumed By:**
- `CalendarViewModel.loadEvents()`
- `TodayView` (for today's events)
- Triggered by: Calendar view appears, date selection changes, pull-to-refresh, app foreground

---

### 10. Sync Events

**File:** `AllTime/Services/APIService.swift`  
**Function:** `syncEvents()`  
**Endpoint:** `POST /sync`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `SyncResponse`
- `status: String`
- `message: String`
- `userId: Int64`
- `eventsSynced: Int`

**Consumed By:**
- `SyncScheduler.performSync()`
- `CalendarManager.syncEvents()`
- Triggered by: Periodic sync (every 15 minutes), app foreground, manual sync

---

### 11. Sync Now (Force Sync)

**File:** `AllTime/Services/APIService.swift`  
**Function:** `syncNow()`  
**Endpoint:** `POST /sync/now`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `SyncResponse`

**Consumed By:**
- `SyncScheduler.forceSync()`
- Triggered by: User manually triggers sync, stale data detected

---

### 12. Sync Google Calendar

**File:** `AllTime/Services/APIService.swift`  
**Function:** `syncGoogleCalendar()`  
**Endpoint:** `POST /sync/google`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `SyncResponse`

**Consumed By:**
- `OAuthManager` after Google OAuth completion
- Triggered by: User connects Google Calendar

---

### 13. Sync Microsoft Calendar

**File:** `AllTime/Services/APIService.swift`  
**Function:** `syncMicrosoftCalendar()`  
**Endpoint:** `POST /sync/microsoft`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `SyncResponse`

**Consumed By:**
- `OAuthManager` after Microsoft OAuth completion
- Triggered by: User connects Microsoft Calendar

---

### 14. Get Event Details

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getEventDetails(eventId:)`  
**Endpoint:** `GET /calendars/events/{eventId}`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `EventDetails`
- `id: Int64`
- `title: String?`
- `description: String?`
- `location: String?`
- `startTime: Date`
- `endTime: Date`
- `allDay: Bool`
- `source: String`
- `sourceEventId: String?`
- `attendees: [Attendee]?`
- `isCancelled: Bool`
- `createdAt: Date`
- `userId: Int64`

**Consumed By:**
- `EventDetailsView` (when user taps an event)
- Triggered by: User taps event in calendar or timeline

---

### 15. Create Event

**File:** `AllTime/Services/APIService.swift`  
**Function:** `createEvent(title:description:location:startDate:endDate:isAllDay:provider:attendees:)`  
**Endpoint:** `POST /calendars/events`  
**Method:** POST

**Parameters:**
```swift
{
  "title": String,
  "description": String?,
  "location": String?,
  "start_time": String,      // ISO8601 UTC format
  "end_time": String,         // ISO8601 UTC format
  "all_day": Bool,
  "provider": String?,         // "google" or "microsoft" (optional)
  "attendees": [String]?      // Array of email addresses
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `CreateEventResponse`
- `id: Int64`
- `title: String`
- `syncStatus: SyncStatus`
  - `provider: String`
  - `synced: Bool`
  - `eventId: String?`
  - `attendeesCount: Int?`
  - `attendees: [String]?`
  - `meetingLink: String?`
  - `meetingType: String?`

**Consumed By:**
- `AddEventView.createEvent()`
- Triggered by: User creates new event in `AddEventView`

**Post-Action:**
- Posts `NotificationCenter.default.post(name: NSNotification.Name("EventCreated"), object: response)`
- `CalendarView` and `TodayView` observe this notification to refresh events

---

### 16. Get Connected Calendars

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getConnectedCalendars()`  
**Endpoint:** `GET /calendars`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `CalendarListResponse`
- `calendars: [ConnectedCalendar]`
- `count: Int`

**Consumed By:**
- `SettingsViewModel.loadConnectedCalendars()`
- `CalendarConnectionView`
- Triggered by: Settings view appears, after OAuth connection

---

### 17. Disconnect Provider

**File:** `AllTime/Services/APIService.swift`  
**Function:** `disconnectProvider(_:)`  
**Endpoint:** `DELETE /calendars/{provider}` (where provider = "google" or "microsoft")  
**Method:** DELETE

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `DeleteCalendarResponse`
- `status: String`
- `message: String`
- `provider: String`

**Consumed By:**
- `SettingsViewModel.disconnectProvider()`
- Triggered by: User taps "Disconnect" in calendar settings

---

### 18. Get Upcoming Events

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getUpcomingEvents(days:)`  
**Endpoint:** `GET /calendars/events/upcoming?days={days}`  
**Method:** GET

**Query Parameters:**
- `days`: Int (default: 7)

**Headers:**
- `Authorization: Bearer <token>`
- `Accept: application/json`

**Response Model:** `EventsResponse`

**Consumed By:**
- `CalendarViewModel` (for upcoming events preview)
- Triggered by: Calendar view loads, date changes

---

### 19. Get Calendar Diagnostics

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getCalendarDiagnostics()`  
**Endpoint:** `GET /calendars/diagnostics`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `CalendarDiagnosticsResponse`
- `connectedProviders: [String]`
- `lastSyncTime: Date?`
- `eventsCount: Int`
- `syncStatus: String`

**Consumed By:**
- Debug/Diagnostics views
- Triggered by: Developer/debug actions

---

### 20. Get Sync Status

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getSyncStatus()`  
**Endpoint:** `GET /sync/status`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `SyncStatusResponse`
- `lastSyncTime: Date?`
- `status: String`
- `eventsSynced: Int`

**Consumed By:**
- `SyncScheduler` (for status checks)
- Triggered by: Sync status checks

---

## Health & Insights APIs

### 21. Submit Daily Health Metrics

**File:** `AllTime/Services/APIService.swift`  
**Function:** `submitDailyHealthMetrics(_:)`  
**Endpoint:** `POST /api/v1/health/daily`  
**Method:** POST

**Parameters:** Single object or array of `DailyHealthMetrics`
```swift
{
  "date": String,                    // yyyy-MM-dd
  "steps": Int?,
  "active_minutes": Int?,
  "stand_minutes": Int?,
  "workouts_count": Int?,
  "resting_heart_rate": Double?,
  "active_heart_rate": Double?,
  "max_heart_rate": Double?,
  "min_heart_rate": Double?,
  "walking_heart_rate_avg": Double?,
  "hrv": Double?,
  "blood_pressure_systolic": Int?,
  "blood_pressure_diastolic": Int?,
  "respiratory_rate": Double?,
  "blood_oxygen_saturation": Double?,
  "active_energy_burned": Double?,
  "basal_energy_burned": Double?,
  "resting_energy_burned": Double?,
  "walking_distance_meters": Double?,
  "running_distance_meters": Double?,
  "cycling_distance_meters": Double?,
  "swimming_distance_meters": Double?,
  "flights_climbed": Int?,
  "sleep_minutes": Int?,
  "sleep_quality_score": Double?,
  "calories_consumed": Double?,
  "protein_grams": Double?,
  "carbs_grams": Double?,
  "fat_grams": Double?,
  "fiber_grams": Double?,
  "water_intake_liters": Double?,
  "caffeine_mg": Double?,
  "body_weight": Double?,
  "body_fat_percentage": Double?,
  "lean_body_mass": Double?,
  "bmi": Double?,
  "blood_glucose": Double?,
  "vo2_max": Double?,
  "mindful_minutes": Int?,
  "menstrual_flow": String?,
  "is_menstrual_period": Bool?
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `SubmitHealthMetricsResponse`
- `recordsUpserted: Int`
- `message: String?`

**Consumed By:**
- `HealthSyncService.performSyncRecentDays()`
- `HealthSyncService.syncLastNDaysToBackend()`
- Triggered by: HealthKit sync after authorization, app foreground, periodic sync

**Flow:**
1. `HealthSyncService.syncRecentDays()` (debounced, 2 seconds)
2. Checks `HealthMetricsService.isAuthorized`
3. Fetches metrics from HealthKit via `HealthMetricsService.fetchDailyMetrics(for:endDate:)`
4. Calls `APIService.submitDailyHealthMetrics()`
5. Updates `lastSyncDate` in UserDefaults

---

### 22. Fetch Health Insights

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchHealthInsights(startDate:endDate:)`  
**Endpoint:** `GET /api/v1/health/insights?start_date={date}&end_date={date}`  
**Method:** GET

**Query Parameters:**
- `start_date`: String (yyyy-MM-dd, optional, defaults to 7 days ago)
- `end_date`: String (yyyy-MM-dd, optional, defaults to today)

**Headers:**
- `Authorization: Bearer <token>`
- `Accept: application/json`

**Response Model:** `HealthInsightsResponse`
- `startDate: String`
- `endDate: String`
- `perDayMetrics: [PerDayMetrics]`
- `summaryStats: SummaryStats?`
- `insights: [String]`

**Consumed By:**
- `HealthInsightsViewModel.loadInsights(startDate:endDate:)`
- Triggered by: "View Insights" button, `LifeWheelView.onAppear`, date range change

**Flow:**
1. User taps "View Insights" in `TodayView` → Navigates to `LifeWheelView`
2. `LifeWheelView.onAppear` → `healthInsightsViewModel.loadInsights()`
3. `HealthInsightsViewModel.loadInsights()` → `APIService.fetchHealthInsights()`
4. Response cached in `HealthInsightsViewModel.cache`
5. UI updates with `HealthInsightsContentView`

---

### 23. Fetch Day Health Insights

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchDayHealthInsights(date:)`  
**Endpoint:** `GET /api/v1/health/insights/day?date={date}`  
**Method:** GET

**Query Parameters:**
- `date`: String (yyyy-MM-dd, optional, defaults to today)

**Headers:**
- `Authorization: Bearer <token>`
- `Accept: application/json`

**Response Model:** `HealthInsightsResponse`

**Consumed By:**
- `HealthInsightsViewModel.loadDayInsights(date:)`
- `TodayView` (for today's health summary)
- Triggered by: Today view appears, after HealthKit authorization, after sync completes

---

## Summary & AI APIs

### 24. Fetch Daily Summary

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchDailySummary(for:)`  
**Endpoint:** `GET /summaries/{date}` (where date = yyyy-MM-dd)  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `DailySummary`
- `date: String`
- `summary: String`
- `highlights: [String]`
- `suggestions: [String]`

**Consumed By:**
- `SummaryManager.fetchTodaySummary()`
- `DailySummaryView`
- Triggered by: App launch, summary view appears

---

### 25. Fetch Today Summary

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchTodaySummary()`  
**Endpoint:** `GET /api/summary/today`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `DailySummary`

**Consumed By:**
- `SummaryManager.fetchTodaySummary()`
- Triggered by: Today view appears, app foreground

---

### 26. Force Generate Summary

**File:** `AllTime/Services/APIService.swift`  
**Function:** `forceGenerateSummary()`  
**Endpoint:** `POST /api/summary/send-now`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `DailySummary`

**Consumed By:**
- `SummaryViewModel` (manual trigger)
- Triggered by: User taps "Generate Summary" button

---

### 27. Fetch Summary Preferences

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchSummaryPreferences()`  
**Endpoint:** `GET /api/summary/preferences`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `SummaryPreferences`
- `timePreference: String?`
- `includeWeather: Bool?`
- `includeTraffic: Bool?`

**Consumed By:**
- `SettingsViewModel`
- Triggered by: Settings view appears

---

### 28. Update Summary Preferences

**File:** `AllTime/Services/APIService.swift`  
**Function:** `updateSummaryPreferences(_:)`  
**Endpoint:** `PUT /api/summary/preferences`  
**Method:** PUT

**Parameters:**
```swift
{
  "time_preference": String?,
  "include_weather": Bool?,
  "include_traffic": Bool?
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response:** Empty (200 OK)

**Consumed By:**
- `SettingsViewModel.updateSummaryPreferences()`
- Triggered by: User saves summary preferences

---

### 29. Fetch Enhanced Daily Summary (v1)

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchDailySummary(date:)`  
**Endpoint:** `GET /api/v1/summary/daily?date={date}`  
**Method:** GET

**Query Parameters:**
- `date`: String (yyyy-MM-dd, optional, defaults to today)

**Headers:**
- `Authorization: Bearer <token>`
- `Accept: application/json`

**Response Model:** `EnhancedDailySummaryResponse`
- `date: String`
- `keyHighlights: [HighlightItem]`
- `potentialIssues: [IssueItem]`
- `suggestions: [SuggestionItem]`
- `dayIntel: DayIntel?`

**Consumed By:**
- `EnhancedDailySummaryViewModel.loadSummary(date:)`
- `DailySummaryView`
- Triggered by: Summary view appears, date selection changes

---

### 30. Fetch Day Timeline (v1)

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchDayTimeline(date:)`  
**Endpoint:** `GET /api/v1/timeline/day?date={date}`  
**Method:** GET

**Query Parameters:**
- `date`: String (yyyy-MM-dd, optional, defaults to today)

**Headers:**
- `Authorization: Bearer <token>`
- `Accept: application/json`

**Response Model:** `TimelineDayResponse`
- `date: String`
- `items: [TimelineItem]` (polymorphic: `EventItem` or `GapItem`)

**Consumed By:**
- `TimelineDayViewModel.loadTimeline(date:)` (defined in `AllTime/Views/TimelineDayView.swift`)
- `TimelineDayView`
- Triggered by: User navigates to timeline view, date changes

---

### 31. Fetch Life Wheel Insights (v1)

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchLifeWheel(start:end:)`  
**Endpoint:** `GET /api/v1/insights/life-wheel?start_date={date}&end_date={date}`  
**Method:** GET

**Query Parameters:**
- `start_date`: String (yyyy-MM-dd, optional, defaults to 7 days ago)
- `end_date`: String (yyyy-MM-dd, optional, defaults to today)

**Headers:**
- `Authorization: Bearer <token>`
- `Accept: application/json`

**Response Model:** `LifeWheelResponse`
- `startDate: String`
- `endDate: String`
- `distribution: [String: ContextDistribution]`
- `totalEvents: Int?`

**Consumed By:**
- `LifeWheelViewModel.loadLifeWheel(start:end:)`
- `LifeWheelView`
- Triggered by: "View Insights" button, `LifeWheelView.onAppear`, date range picker changes

**Flow:**
1. User taps "View Insights" in `TodayView` → Navigates to `LifeWheelView`
2. `LifeWheelView.onAppear` → `lifeWheelViewModel.loadLifeWheel()`
3. `LifeWheelViewModel.loadLifeWheel()` → `APIService.fetchLifeWheel()`
4. Response displayed in `LifeWheelContentView`

---

### 32. Fetch Daily AI Summary

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getDailyAISummary(date:)`  
**Endpoint:** `GET /api/ai/daily-summary?date={date}`  
**Method:** GET

**Query Parameters:**
- `date`: String (yyyy-MM-dd, optional, defaults to today)

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response Model:** `DailyAISummaryResponse`
- `date: String`
- `totalEvents: Int`
- `keyHighlights: [String]`
- `risksOrConflicts: [String]`
- `suggestions: [String]`

**Consumed By:**
- `SummaryViewModel` (legacy)
- Triggered by: Summary view appears

---

### 33. Fetch Summary History

**File:** `AllTime/Services/APIService.swift`  
**Function:** `fetchSummaryHistory(startDate:endDate:)`  
**Endpoint:** `GET /api/summary/history?start={date}&end={date}`  
**Method:** GET

**Query Parameters:**
- `start`: String (date string)
- `end`: String (date string)

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `SummaryHistoryResponse`
- `summaries: [DailySummary]`

**Consumed By:**
- Summary history views
- Triggered by: User views summary history

---

## OAuth & Provider APIs

### 34. Get Google OAuth Start URL

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getGoogleOAuthStartURL()`  
**Endpoint:** `GET /connections/google/start`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:**
```json
{
  "oauth_url": String
}
```

**Consumed By:**
- `GoogleAuthManager.startOAuthFlow()`
- `OAuthManager.connectGoogle()`
- Triggered by: User taps "Connect Google" in settings

**Flow:**
1. User taps "Connect Google Calendar"
2. `GoogleAuthManager.startOAuthFlow()` → `APIService.getGoogleOAuthStartURL()`
3. Opens `ASWebAuthenticationSession` with OAuth URL
4. User authorizes → Callback URL intercepted
5. `GoogleAuthManager` extracts code → `APIService.completeGoogleOAuth()`

---

### 35. Complete Google OAuth

**File:** `AllTime/Services/APIService.swift`  
**Function:** `completeGoogleOAuth(code:)`  
**Endpoint:** `POST /connections/google/callback`  
**Method:** POST

**Parameters:**
```swift
{
  "code": String  // OAuth authorization code
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response:** Empty (200 OK)

**Consumed By:**
- `GoogleAuthManager` (after OAuth callback)
- Triggered by: OAuth callback URL received

---

### 36. Get Microsoft OAuth Start URL

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getMicrosoftOAuthStartURL()`  
**Endpoint:** `GET /connections/microsoft/start`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:**
```json
{
  "oauth_url": String
}
```

**Consumed By:**
- `MicrosoftAuthManager.startOAuthFlow()`
- `OAuthManager.connectMicrosoft()`
- Triggered by: User taps "Connect Microsoft" in settings

---

### 37. Complete Microsoft OAuth

**File:** `AllTime/Services/APIService.swift`  
**Function:** `completeMicrosoftOAuth(code:)`  
**Endpoint:** `POST /connections/microsoft/callback`  
**Method:** POST

**Parameters:**
```swift
{
  "code": String  // OAuth authorization code
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response:** Empty (200 OK)

**Consumed By:**
- `MicrosoftAuthManager` (after OAuth callback)
- Triggered by: OAuth callback URL received

---

### 38. Get Google Connection Status

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getGoogleConnectionStatus()`  
**Endpoint:** `GET /connections/google/status`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `ConnectionStatus`
- `connected: Bool`
- `provider: String`
- `displayName: String?`

**Consumed By:**
- `SettingsViewModel.loadConnectionStatus()`
- Triggered by: Settings view appears

---

### 39. Get Microsoft Connection Status

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getMicrosoftConnectionStatus()`  
**Endpoint:** `GET /connections/microsoft/status`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `ConnectionStatus`

**Consumed By:**
- `SettingsViewModel.loadConnectionStatus()`
- Triggered by: Settings view appears

---

## Push Notification APIs

### 40. Register Device Token

**File:** `AllTime/Services/APIService.swift`  
**Function:** `registerDeviceToken(_:)`  
**Endpoint:** `POST /push/register`  
**Method:** POST

**Parameters:**
```swift
{
  "deviceToken": String  // APNs device token
}
```

**Headers:**
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

**Response:** Empty (200 OK)

**Consumed By:**
- `PushNotificationManager.registerForPushNotifications()`
- Triggered by: App launch, user grants notification permission

---

### 41. Send Test Notification

**File:** `AllTime/Services/APIService.swift`  
**Function:** `sendTestNotification()`  
**Endpoint:** `POST /push/test`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response:** Empty (200 OK)

**Consumed By:**
- `NotificationSettingsView` (test button)
- Triggered by: User taps "Send Test Notification"

---

### 42. Send Daily Summary Notification

**File:** `AllTime/Services/APIService.swift`  
**Function:** `sendDailySummaryNotification()`  
**Endpoint:** `POST /push/test`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response:** Empty (200 OK)

**Consumed By:**
- `NotificationService` (scheduled notifications)
- Triggered by: Scheduled daily summary time

---

### 43. Send Calendar Sync Notification

**File:** `AllTime/Services/APIService.swift`  
**Function:** `sendCalendarSyncNotification()`  
**Endpoint:** `POST /api/push/calendar-sync`  
**Method:** POST

**Headers:**
- `Authorization: Bearer <token>`

**Response:** Empty (200 OK)

**Consumed By:**
- `NotificationService` (after sync completion)
- Triggered by: Calendar sync completes

---

### 44. Get Push Notification Status

**File:** `AllTime/Services/APIService.swift`  
**Function:** `getPushNotificationStatus()`  
**Endpoint:** `GET /api/push/status`  
**Method:** GET

**Headers:**
- `Authorization: Bearer <token>`

**Response Model:** `PushNotificationStatus`
- `enabled: Bool`
- `deviceToken: String?`
- `lastNotificationTime: Date?`

**Consumed By:**
- `NotificationSettingsView`
- Triggered by: Notification settings view appears

---

## Health Check API

### 45. Health Check

**File:** `AllTime/Services/APIService.swift`  
**Function:** `healthCheck()`  
**Endpoint:** `GET /health`  
**Method:** GET

**Headers:** None (public endpoint)

**Response:**
```json
{
  "status": "OK"
}
```

**Consumed By:**
- `APIService.testBackendConnection()`
- Triggered by: App launch, connection diagnostics

---

## HealthKit Authorization Flow

### Overview

HealthKit authorization is managed by `HealthKitManager` and follows a strict state machine to prevent infinite loops and handle denied permissions correctly.

**File:** `AllTime/Services/HealthKitManager.swift`

**State Machine:**
```swift
enum HealthPermissionState {
    case unknown
    case notDetermined
    case requesting
    case authorized
    case denied  // Permanently denied - iOS won't show popup
}
```

### Authorization Request Flow

**Trigger Points:**
1. **Primary:** `PremiumTabView.onAppear` (after user logs in and dashboard is visible)
2. **Secondary:** `HealthPermissionsViewModel.tapEnableHealthButton()` (user taps "Enable Health Data")

**Flow Diagram:**
```
App Launch
    ↓
User Logs In
    ↓
PremiumTabView.onAppear
    ↓
HealthKitManager.safeRequestIfNeeded()
    ↓
Check HealthKit availability + scan canonical types for `.notDetermined`
    ↓
┌────────────────────────────────────────────┐
│ Permission Sheet Logic                     │
├────────────────────────────────────────────┤
│ Any type is .notDetermined?                │
│   → Set state = .requesting                │
│   → Immediately call requestAuthorization  │
│   → iOS shows the HealthKit sheet once     │
│                                            │
│ No types are .notDetermined?               │
│   → Assume the user already responded      │
│   → Set state = .authorized                │
│   → Proceed directly to syncing            │
└────────────────────────────────────────────┘
    ↓
requestAuthorization() (if needed)
    ↓
healthStore.requestAuthorization(toShare: [], read: readTypes)
    ↓
Completion Handler:
    - Log success/error
    - Mark permissionState = .authorized regardless
    - Trigger HealthSyncService.syncRecentDays()
```

### HealthKit Sync Flow

**File:** `AllTime/Services/HealthSyncService.swift`

**Flow Diagram:**
```
HealthSyncService.syncRecentDays() (debounced, 2s)
    ↓
performSyncRecentDays()
    ↓
Check HealthMetricsService.isAuthorized (readiness flag only)
    ↓
Log readiness but always continue (read permission cannot be queried)
    ↓
Determine date range:
        - First sync: Last 14 days
        - Subsequent: From lastSyncDate to today
    ↓
HealthMetricsService.fetchDailyMetrics(for:startDate:endDate:)
    ↓
Query HealthKit for each day:
    - Steps
    - Active Energy
    - Active Minutes
    - Stand Minutes
    - Resting Heart Rate
    - HRV
    - Sleep
    - Workouts
    - (and 20+ other metrics)
    ↓
Aggregate per day → [DailyHealthMetrics]
    ↓
APIService.submitDailyHealthMetrics(metrics)
    ↓
POST /api/v1/health/daily
    ↓
Update lastSyncDate in UserDefaults
```

**Trigger Points:**
1. **App Launch:** `ContentView.initializeAppData()` → `HealthSyncService.syncRecentDays()`
2. **App Foreground:** `ContentView.handleScenePhaseChange(.active)` → `HealthSyncService.syncRecentDays()`
3. **After Authorization:** `HealthKitManager.performAuthorization()` completion → `HealthSyncService.syncRecentDays()` (after 2s delay)
4. **Manual:** `HealthPermissionsViewModel.tapEnableHealthButton()` → `triggerInitialSync()` → `HealthSyncService.syncLastNDaysToBackend(14)`

---

## Call Graphs & Flowcharts

### "View Insights" Button Call Graph

```
TodayView
    ↓
User taps "View Insights" button
    ↓
NavigationLink(destination: LifeWheelView())
    ↓
LifeWheelView appears
    ↓
.onAppear {
    ├─→ healthMetricsService.checkAuthorizationStatus()
    │   └─→ HealthMetricsService.checkAuthorizationStatus()
    │       └─→ Checks authorizationStatus(for:) for all 8 core types
    │
    └─→ Parallel API Calls:
        ├─→ healthInsightsViewModel.loadInsights(startDate:endDate:)
        │   └─→ HealthInsightsViewModel.loadInsights()
        │       ├─→ Check cache (return if cached)
        │       ├─→ Cancel in-flight tasks
        │       ├─→ Debounce 0.1s
        │       └─→ APIService.fetchHealthInsights(startDate:endDate:)
        │           └─→ GET /api/v1/health/insights?start_date={date}&end_date={date}
        │               └─→ Response: HealthInsightsResponse
        │                   └─→ Update HealthInsightsViewModel.insights
        │                       └─→ UI: HealthInsightsContentView
        │
        └─→ lifeWheelViewModel.loadLifeWheel(start:end:)
            └─→ LifeWheelViewModel.loadLifeWheel()
                └─→ APIService.fetchLifeWheel(start:end:)
                    └─→ GET /api/v1/insights/life-wheel?start_date={date}&end_date={date}
                        └─→ Response: LifeWheelResponse
                            └─→ Update LifeWheelViewModel.lifeWheel
                                └─→ UI: LifeWheelContentView (fallback if no health insights)
```

**Date Range Changes:**
```
User changes range picker (7/14/30 days)
    ↓
.onChange(of: selectedRange)
    ↓
Parallel API Calls:
    ├─→ healthInsightsViewModel.loadInsights(newRange.startDate, Date())
    └─→ lifeWheelViewModel.loadLifeWheel(newRange.startDate, Date())
```

---

### HealthKit Sync Invocation Flowchart

```
┌─────────────────────────────────────────────────────────────┐
│ HealthKit Sync Trigger Points                                │
└─────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│ App Launch    │   │ App Foreground│   │ After Auth    │
└───────────────┘   └───────────────┘   └───────────────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │ HealthSyncService.syncRecentDays()│
            │ (Debounced: 2 seconds)        │
            └───────────────────────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │ performSyncRecentDays()        │
            └───────────────────────────────┘
                            │
                            ▼
            ┌───────────────────────────────┐
            │ Check Authorization           │
            │ HealthMetricsService.isAuthorized│
            └───────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
        ┌───────────────┐       ┌───────────────┐
        │ Not Authorized │       │ Authorized    │
        │ → Skip Sync    │       │ → Continue    │
        └───────────────┘       └───────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ Determine Date Range           │
                        │ - First: Last 14 days          │
                        │ - Subsequent: lastSyncDate→today│
                        └───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ Fetch from HealthKit          │
                        │ HealthMetricsService.fetchDailyMetrics()│
                        └───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ Query HealthKit (per day):    │
                        │ - Steps, Energy, Minutes      │
                        │ - Heart Rate, HRV             │
                        │ - Sleep, Workouts             │
                        │ - (20+ other metrics)         │
                        └───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ Aggregate → [DailyHealthMetrics]│
                        └───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ POST to Backend               │
                        │ APIService.submitDailyHealthMetrics()│
                        │ POST /api/v1/health/daily     │
                        └───────────────────────────────┘
                                        │
                                        ▼
                        ┌───────────────────────────────┐
                        │ Update lastSyncDate            │
                        │ Save to UserDefaults           │
                        └───────────────────────────────┘
```

---

## HealthKit Authorization Status Checks

### All Locations Where `authorizationStatus()` is Checked

1. **HealthKitManager.swift**
   - **Line 56:** `safeRequestIfNeeded()` - Checks all 8 types before requesting
   - **Line 119:** `debugPrintStatuses()` - Debug function to print all statuses

2. **HealthMetricsService.swift**
   - **Line 67:** `checkAuthorizationStatus()` - Checks all core types to determine `isAuthorized`
   - **Line 143:** `verifyAuthorizationByQuery()` - Checks status before attempting query
   - **Line 194:** `verifyWithActualQuery()` - Checks step count type status before querying

3. **ContentView.swift**
   - **Line 117:** `handleScenePhaseChange(.active)` - Re-checks authorization when app becomes active

4. **LifeWheelView.swift**
   - **Line 106:** `onAppear` - Checks authorization status when Insights view appears
   - **Line 59:** `HealthPermissionCard.onRequestPermission` - Checks before opening Health app

5. **TodayView.swift**
   - **Line 778:** `onAppear` - Checks authorization in `refreshAuthStateOnAppear()`

6. **HealthSyncService.swift**
   - **Line 62:** `performSyncRecentDays()` - Checks authorization before syncing
   - **Line 132:** `syncLastNDaysToBackend()` - Checks authorization before syncing

### Authorization Check Pattern

All authorization checks follow this pattern:

```swift
// 1. Get all core types
let coreTypes = HealthKitCoreTypes.readTypes  // 8 types

// 2. Check status for each type
for type in coreTypes {
    let status = healthStore.authorizationStatus(for: type)
    // status is one of: .notDetermined, .sharingDenied, .sharingAuthorized
}

// 3. Determine overall state
if any type is .sharingAuthorized → isAuthorized = true
if all types are .sharingDenied → isAuthorized = false, show denied UI
if any type is .notDetermined → isAuthorized = false, can request
```

---

## Summary

### Total API Endpoints: 45

**By Category:**
- Authentication: 4 endpoints
- User Profile: 4 endpoints
- Calendar & Events: 12 endpoints
- Health & Insights: 3 endpoints
- Summary & AI: 10 endpoints
- OAuth & Provider: 6 endpoints
- Push Notifications: 5 endpoints
- Health Check: 1 endpoint

### Key Integration Points

1. **HealthKit → Backend Sync:**
   - `HealthKitManager` → `HealthSyncService` → `APIService.submitDailyHealthMetrics()`
   - Triggered: After authorization, app foreground, periodic sync

2. **Insights View:**
   - `LifeWheelView` → `HealthInsightsViewModel` + `LifeWheelViewModel`
   - Calls: `GET /api/v1/health/insights` + `GET /api/v1/insights/life-wheel`
   - Triggered: "View Insights" button, view appears, date range changes

3. **Calendar Sync:**
   - `SyncScheduler` → `APIService.syncEvents()` or `syncGoogleCalendar()` / `syncMicrosoftCalendar()`
   - Triggered: Periodic (15 min), app foreground, manual sync

4. **Event Creation:**
   - `AddEventView` → `APIService.createEvent()`
   - Post-action: Posts notification → `CalendarView` and `TodayView` refresh

---

## Notes

- All API calls use JWT Bearer token authentication (except `/health`)
- Date formats: `yyyy-MM-dd` for query parameters, ISO8601 for event times
- HealthKit sync is debounced (2 seconds) to prevent spam
- Health insights are cached per date range in `HealthInsightsViewModel`
- All network calls are performed off main thread using `Task.detached`
- Error handling includes detailed logging and user-friendly error messages

---

**Documentation Generated:** $(date)  
**Last Updated:** Based on current codebase analysis

