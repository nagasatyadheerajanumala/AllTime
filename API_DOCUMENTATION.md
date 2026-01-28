# AllTime Backend API Documentation

**Base URL:** `https://alltime-backend-756952284083.us-central1.run.app`

**Authentication:** All endpoints (except `/auth/*` and OAuth callbacks) require JWT Bearer token authentication.

```
Authorization: Bearer <access_token>
```

---

## Table of Contents

1. [Authentication](#1-authentication)
2. [User Management](#2-user-management)
3. [Calendar Connections (OAuth)](#3-calendar-connections-oauth)
4. [Calendar Sync](#4-calendar-sync)
5. [Events](#5-events)
6. [Tasks](#6-tasks)
7. [Reminders](#7-reminders)
8. [Time Intelligence](#8-time-intelligence)
9. [Weekly Insights](#9-weekly-insights)
10. [Health Insights](#10-health-insights)
11. [Life Insights](#11-life-insights)
12. [Push Notifications](#12-push-notifications)
13. [Error Handling](#13-error-handling)

---

## 1. Authentication

### POST /auth/apple
**Sign in with Apple**

```json
// Request
{
  "identityToken": "eyJ...",
  "email": "user@example.com",  // Optional, provided on first sign-in
  "fullName": "John Doe"        // Optional
}

// Response (200)
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 86400,
  "refresh_expires_in": 31536000,
  "user": {
    "id": 1,
    "email": "user@example.com",
    "fullName": "John Doe",
    "profileSetup": true
  }
}
```

### POST /auth/refresh
**Refresh access token**

```json
// Request
{
  "refreshToken": "eyJ..."
}

// Response (200)
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",  // New refresh token (rotation)
  "token_type": "Bearer",
  "expires_in": 86400,
  "refresh_expires_in": 31536000
}
```

### POST /auth/logout
**Logout (client-side token removal)**

```json
// Response (200)
{
  "message": "Logged out successfully"
}
```

---

## 2. User Management

### GET /api/user/me
**Get current user profile**

```json
// Response (200)
{
  "id": 1,
  "email": "user@example.com",
  "fullName": "John Doe",
  "firstName": "John",
  "profilePictureUrl": "https://...",
  "timezone": "America/New_York",
  "profileSetup": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### PUT /api/user/update
**Update user profile**

```json
// Request
{
  "fullName": "John Smith",
  "timezone": "America/Los_Angeles"
}

// Response (200)
{
  "id": 1,
  "fullName": "John Smith",
  "timezone": "America/Los_Angeles",
  ...
}
```

### POST /api/user/profile/setup
**Initial profile setup (new users)**

```json
// Request
{
  "fullName": "John Doe",
  "timezone": "America/New_York"
}
```

### POST /api/user/profile/picture
**Update profile picture**

```json
// Request
{
  "profile_picture_url": "https://..."
}
```

### GET /api/user/preferences/holidays
**Get holiday sync preference**

```json
// Response (200)
{
  "syncHolidays": true,
  "message": "Holiday sync is enabled"
}
```

### PUT /api/user/preferences/holidays
**Update holiday sync preference**

```json
// Request
{
  "syncHolidays": false
}

// Response (200)
{
  "syncHolidays": false,
  "message": "Holiday sync disabled. Existing holiday events have been removed.",
  "holidaysDeleted": true
}
```

---

## 3. Calendar Connections (OAuth)

### GET /connections/google/start
**Initiate Google OAuth flow**

```json
// Response (200)
{
  "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?..."
}
```

### GET /connections/google/callback
**Google OAuth callback** (redirects to `alltime://oauth/success` or `alltime://oauth/error`)

### GET /connections/google/status
**Get Google connection status**

```json
// Response (200) - Connected
{
  "connected": true,
  "external_user_id": "google_user_1",
  "email": "user@gmail.com",
  "expires_at": "2024-01-01T12:00:00"
}

// Response (200) - Not connected
{
  "connected": false
}
```

### GET /connections/google/accounts
**Get all connected Google accounts (multi-account)**

```json
// Response (200)
{
  "accounts": [
    {
      "id": 1,
      "provider": "google",
      "email": "user@gmail.com",
      "expires_at": "2024-01-01T12:00:00"
    }
  ],
  "count": 1
}
```

### DELETE /connections/google/accounts/{connectionId}
**Disconnect a Google account**

---

## 4. Calendar Sync

### POST /sync
**Sync all calendars**

```json
// Response (200)
{
  "status": "success",
  "message": "Calendars synced successfully",
  "total_events_synced": 42,
  "user_id": 1
}
```

### POST /sync/google
**Sync Google Calendar only**

```json
// Response (200)
{
  "status": "success",
  "message": "Google Calendar synced successfully",
  "total_events_synced": 35,
  "diagnostics": {
    "total_events_in_database": 100,
    "google_events_in_database": 75,
    "upcoming_events_in_database": 50
  }
}

// Response (401) - Token expired
{
  "error": "token_expired",
  "provider": "google",
  "message": "Google Calendar token expired or revoked. User must reconnect.",
  "action_required": "reconnect_calendar"
}
```

### POST /sync/microsoft
**Sync Microsoft Calendar only**

### GET /sync/status
**Get sync status**

```json
// Response (200)
{
  "last_synced_at": "2024-01-01T12:00:00",
  "sync_in_progress": false,
  "needs_reconnect": false,
  "connections": [
    {
      "provider": "google",
      "email": "user@gmail.com",
      "status": "active",
      "needs_reconnect": false,
      "last_synced": "2024-01-01T12:00:00",
      "consecutive_failures": 0
    }
  ]
}
```

### GET /sync/connection-health
**Check connection health**

```json
// Response (200)
{
  "healthy": true,
  "needs_reconnect": false,
  "connections": [
    {
      "provider": "google",
      "email": "user@gmail.com",
      "status": "active",
      "needs_reconnect": false
    }
  ]
}
```

### GET /sync/diagnostic
**Detailed sync diagnostics**

---

## 5. Events

### GET /events
**Get events with auto-sync**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start` | string | -365 days | ISO 8601 datetime |
| `end` | string | +365 days | ISO 8601 datetime |
| `days` | integer | 365 | Days to fetch |
| `period` | string | "custom" | "day", "week", "month", "year", "custom" |
| `autoSync` | boolean | true | Auto-sync calendars before fetch |
| `page` | integer | 1 | Pagination |
| `limit` | integer | 50 | Events per page |

```json
// Response (200)
{
  "events": [
    {
      "id": 1,
      "title": "Meeting with team",
      "description": "Quarterly review",
      "location": "Conference Room A",
      "start_time": "2024-01-01T10:00:00Z",
      "end_time": "2024-01-01T11:00:00Z",
      "all_day": false,
      "source": "google",
      "event_type": "meeting",
      "event_color": "#4285F4",
      "meeting_link": "https://meet.google.com/xxx",
      "attendees": [{"email": "colleague@example.com"}]
    }
  ],
  "summary": {
    "total_events": 100,
    "meetings": 45,
    "focus_blocks": 20,
    "personal": 35
  },
  "time_range": {
    "start": "2024-01-01T00:00:00Z",
    "end": "2024-12-31T23:59:59Z",
    "description": "Past year to next year"
  },
  "sync_status": "synced"
}
```

### GET /calendars/events/upcoming
**Get upcoming events**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `days` | integer | 7 | Days ahead to fetch |

### GET /calendars/events/{eventId}
**Get event details**

```json
// Response (200)
{
  "id": 1,
  "title": "Meeting with team",
  "description": "Quarterly review",
  "location": "Conference Room A",
  "start_time": "2024-01-01T10:00:00Z",
  "end_time": "2024-01-01T11:00:00Z",
  "all_day": false,
  "source": "google",
  "source_event_id": "abc123",
  "meeting_link": "https://meet.google.com/xxx",
  "html_link": "https://calendar.google.com/...",
  "organizer_email": "organizer@example.com",
  "attendees": [{"email": "colleague@example.com"}],
  "reminders": [],
  "reminders_count": 0
}
```

### POST /calendars/events
**Create a new event**

```json
// Request
{
  "title": "Project meeting",
  "description": "Discuss Q1 goals",
  "location": "Conference Room B",
  "startTime": "2024-01-15T14:00:00Z",
  "endTime": "2024-01-15T15:00:00Z",
  "allDay": false,
  "provider": "google",  // "google", "microsoft", or null for local
  "attendees": ["colleague@example.com"],
  "addGoogleMeet": true,
  "eventColor": "#4285F4"
}

// Response (201)
{
  "id": 1,
  "title": "Project meeting",
  "start_time": "2024-01-15T14:00:00Z",
  "end_time": "2024-01-15T15:00:00Z",
  "source": "google",
  "sync_status": {
    "provider": "google",
    "synced": true,
    "googleSync": {
      "status": "success",
      "event_id": "abc123"
    },
    "invitations": {
      "status": "sent",
      "sent": true,
      "attendees_count": 1,
      "message": "Email invitations sent to 1 attendee(s) via Google Calendar"
    }
  }
}
```

### DELETE /calendars/{provider}
**Disconnect a calendar provider**

| Path Parameter | Description |
|----------------|-------------|
| `provider` | "google" or "microsoft" |

---

## 6. Tasks

### POST /api/v1/tasks/quick
**Quick add a task (AI enhances)**

```json
// Request
{
  "title": "Review Q4 report",
  "source": "quick_add"
}

// Response (200)
{
  "id": 1,
  "title": "Review Q4 report",
  "status": "PENDING",
  "priority": 2,
  "estimatedMinutes": 30,
  "suggestedTime": "2024-01-01T14:00:00Z",
  "aiReason": "Scheduled during your typical focus time"
}
```

### POST /api/v1/tasks
**Create task with full details**

```json
// Request
{
  "title": "Prepare presentation",
  "description": "Q1 board presentation",
  "priority": 1,
  "dueDate": "2024-01-15",
  "estimatedMinutes": 120,
  "category": "work"
}
```

### GET /api/v1/tasks/all
**Get all tasks with categorization**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `timezone` | string | America/Los_Angeles | User timezone |

```json
// Response (200)
{
  "tasks": [...],          // All active tasks
  "openTasks": [...],      // Not overdue
  "catchUpTasks": [...],   // Overdue
  "doneTasks": [...],      // Completed today
  "openCount": 5,
  "catchUpCount": 2,
  "doneToday": 3
}
```

### GET /api/v1/tasks/today
**Get today's tasks (Up Next section)**

```json
// Response (200)
{
  "tasks": [...],
  "totalCount": 5,
  "overdueCount": 1,
  "highPriorityCount": 2
}
```

### GET /api/v1/tasks/open
**Get open (non-overdue) tasks**

### GET /api/v1/tasks/catchup
**Get overdue tasks**

### GET /api/v1/tasks/done
**Get completed tasks (today)**

### PUT /api/v1/tasks/{id}
**Update a task**

### PUT /api/v1/tasks/{id}/status
**Update task status**

```json
// Request
{
  "status": "COMPLETED"  // PENDING, SCHEDULED, IN_PROGRESS, COMPLETED, DEFERRED, CANCELLED
}
```

### POST /api/v1/tasks/{id}/complete
**Mark task as completed**

```json
// Request (optional)
{
  "actual_duration_minutes": 45
}
```

### DELETE /api/v1/tasks/{id}
**Delete a task**

### POST /api/v1/tasks/schedule
**Auto-schedule pending tasks**

```json
// Request
{
  "date": "2024-01-15",
  "timezone": "America/Los_Angeles"
}

// Response (200)
{
  "scheduledTasks": [...],
  "scheduledCount": 3,
  "message": "Scheduled 3 tasks"
}
```

### GET /api/v1/tasks/{id}/suggest
**Get AI scheduling suggestion for a task**

---

## 7. Reminders

### POST /api/v1/reminders
**Create a reminder**

```json
// Request
{
  "title": "Call John",
  "scheduledAt": "2024-01-15T10:00:00Z",
  "eventId": 1,                    // Optional, link to event
  "recurrenceRule": "FREQ=WEEKLY", // Optional, iCal RRULE
  "priority": 1,
  "estimatedMinutes": 15,
  "notes": "Discuss project updates"
}

// Response (201)
{
  "id": 1,
  "title": "Call John",
  "status": "pending",
  "scheduledAt": "2024-01-15T10:00:00Z",
  ...
}
```

### GET /api/v1/reminders
**Get all reminders**

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status: "pending", "completed", "snoozed" |

### GET /api/v1/reminders/range
**Get reminders in date range**

| Parameter | Type | Description |
|-----------|------|-------------|
| `start_date` | datetime | ISO 8601 |
| `end_date` | datetime | ISO 8601 |

### GET /api/v1/reminders/{id}
**Get a specific reminder**

### PUT /api/v1/reminders/{id}
**Update a reminder**

### POST /api/v1/reminders/{id}/complete
**Mark reminder as completed**

### POST /api/v1/reminders/{id}/snooze
**Snooze a reminder**

```json
// Request
{
  "snooze_until": "2024-01-15T14:00:00Z"
}
```

### DELETE /api/v1/reminders/{id}
**Delete a reminder**

### GET /api/v1/reminders/event/{eventId}
**Get reminders for an event**

### GET /api/v1/reminders/prioritized
**Get AI-prioritized reminders**

```json
// Response (200)
{
  "do_this_first": {
    "reminder": {...},
    "reason": "Quick win - only 10 minutes"
  },
  "prioritized": [
    {
      "reminder": {...},
      "reason": "...",
      "category": "quick_win"  // quick_win, needs_attention, deep_work, regular
    }
  ],
  "summary": {
    "total_pending": 10,
    "quick_wins": 3,
    "being_avoided": 2,
    "overdue": 1,
    "total_estimated_minutes": 240
  }
}
```

### GET /api/v1/reminders/{id}/preview
**Preview recurring reminder instances**

---

## 8. Time Intelligence

### GET /intelligence/today
**Get today's intelligence (main endpoint)**

```json
// Response (200)
{
  "date": "2024-01-15",
  "directive": {
    "text": "Protect your morning focus block.",
    "type": "protect",
    "confidence": 85
  },
  "capacity": {
    "overloadPercent": 35,
    "recoveryDeficit": 15,
    "consecutiveHighLoadDays": 2,
    "status": "manageable"
  },
  "metrics": {
    "meetingCount": 4,
    "meetingMinutes": 180,
    "focusBlocks": 2,
    "largestFocusBlockMinutes": 90
  },
  "declineRecommendations": [
    {
      "id": 1,
      "meetingTitle": "Optional sync",
      "reason": "Low value, conflicts with focus time",
      "confidence": 78
    }
  ],
  "interventionUrgency": "low"
}
```

### GET /intelligence/{date}
**Get intelligence for a specific date**

### GET /intelligence/directive
**Get just the directive (fast, for widgets)**

```json
// Response (200)
{
  "directive": "Execute your priorities.",
  "type": "execute",
  "confidence": 70,
  "overloadPercent": 0,
  "interventionUrgency": "none"
}
```

### GET /intelligence/summary
**Get natural language summary**

```json
// Response (200)
{
  "summary": "Manageable day. You have a 90-minute focus block. Guard it.",
  "date": "2024-01-15"
}
```

### GET /intelligence/decline-recommendations
**Get pending decline recommendations**

### POST /intelligence/decline-recommendations/{id}/action
**Record action on decline recommendation**

```json
// Request
{
  "action": "declined",  // declined, rescheduled, attended_anyway, ignored
  "wasPositive": true
}
```

### POST /intelligence/decline-recommendations/{id}/dismiss
**Dismiss a recommendation**

---

## 9. Weekly Insights

### GET /api/v1/insights/weekly
**Get weekly insights summary**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `weekStart` | string | Current week | ISO date (Monday) |
| `timezone` | string | America/New_York | User timezone |

```json
// Response (200)
{
  "weekStart": "2024-01-08",
  "weekEnd": "2024-01-14",
  "summary": {
    "totalMeetingHours": 22.5,
    "totalFocusHours": 15,
    "meetingCount": 28,
    "backToBackCount": 8,
    "lateMeetingCount": 3
  },
  "patterns": {
    "busiestDay": "Wednesday",
    "busiestDayHours": 6.5,
    "lightestDay": "Friday",
    "averageDailyMeetingHours": 4.5
  },
  "highlights": [...],
  "concerns": [...],
  "nextWeekFocus": [...]
}
```

### GET /api/v1/insights/weekly/narrative
**Get AI-generated weekly narrative**

```json
// Response (200)
{
  "overallTone": "Balanced",  // Calm, Balanced, Overloaded, Draining
  "weeklyOverview": "A productive week with good balance between meetings and focus time.",
  "timeBuckets": [
    {"category": "Meetings", "hours": 22.5, "label": "22h 30m"}
  ],
  "energyAlignment": {
    "label": "Well-aligned",
    "summary": "Your heavy days matched your typical energy patterns.",
    "evidence": [...]
  },
  "stressSignals": [
    {"title": "Back-to-back streak", "evidence": "8 back-to-back meetings on Wed-Thu"}
  ],
  "suggestions": [
    {"title": "Protect Friday mornings", "why": "Your lightest day - perfect for deep work", "action": "Block 9-11am"}
  ],
  "aggregates": {...}
}
```

### GET /api/v1/insights/weekly/available
**Get available weeks (last 8 weeks)**

```json
// Response (200)
{
  "weeks": [
    {"weekStart": "2024-01-08", "weekEnd": "2024-01-14", "label": "This Week"},
    {"weekStart": "2024-01-01", "weekEnd": "2024-01-07", "label": "Last Week"},
    ...
  ],
  "currentWeek": "2024-01-08"
}
```

### POST /api/v1/insights/weekly/refresh
**Force refresh weekly insights**

### GET /api/v1/insights/week-drift
**Get week drift status (forward-looking)**

```json
// Response (200)
{
  "driftScore": 35,  // 0-100, 0 = on track
  "severity": "watch",  // on_track, watch, drifting, critical
  "headline": "You're slightly behind on focus time this week",
  "interventions": [
    {"action": "Block 2 hours tomorrow morning", "impact": "high"}
  ]
}
```

### GET /api/v1/insights/next-week-forecast
**Get next week forecast**

```json
// Response (200)
{
  "headline": "Heavy week ahead - 28 meetings scheduled",
  "weekMetrics": {
    "totalMeetings": 28,
    "totalMeetingHours": 24,
    "heavyDays": ["Tuesday", "Wednesday"],
    "focusHours": 12
  },
  "dailyForecasts": [
    {"day": "Monday", "intensity": "moderate", "meetingHours": 4}
  ],
  "riskSignals": [...],
  "interventions": [...]
}
```

### GET /api/v1/insights/pattern-intelligence
**Get pattern-based intelligence**

### GET /api/v1/insights/today-prediction
**Get today's prediction based on historical patterns**

### GET /api/v1/insights/daily
**Get daily summary (for notifications)**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `date` | string | today | ISO date |
| `timezone` | string | America/New_York | User timezone |

---

## 10. Health Insights

### POST /api/v1/health/daily
**Upsert daily health metrics**

```json
// Request (single or array)
{
  "date": "2024-01-15",
  "steps": 8500,
  "active_minutes": 45,
  "sleep_minutes": 420,
  "sleep_quality_score": 85,
  "resting_heart_rate": 62,
  "hrv": 45,
  "workouts_count": 1,
  "active_energy_burned": 450
}

// Response (200)
{
  "status": "success",
  "recordsUpserted": 1,
  "recordsFailed": 0,
  "syncedDates": ["2024-01-15"]
}
```

### GET /api/v1/health/insights
**Get health + calendar insights**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `start_date` | date | -6 days | ISO date |
| `end_date` | date | today | ISO date |

```json
// Response (200)
{
  "dateRange": {"start": "2024-01-09", "end": "2024-01-15"},
  "summary": {
    "avgSleepHours": 7.2,
    "avgSteps": 8200,
    "avgRestingHeartRate": 62
  },
  "insights": [
    {
      "type": "sleep_pattern",
      "title": "Sleep consistency improving",
      "description": "Your sleep duration variance decreased by 15%"
    }
  ],
  "perDayMetrics": [...]
}
```

### GET /api/v1/health/insights/day
**Get single day health insights**

### GET /api/v1/health/energy-patterns
**Get energy pattern correlations**

```json
// Response (200)
{
  "patterns": [
    {
      "type": "meeting_sleep",
      "title": "Heavy meeting days affect sleep",
      "description": "On 4+ meeting days, you sleep 45 min less",
      "evidence": {...}
    }
  ],
  "recommendations": [...]
}
```

### GET /api/v1/health/similar-week
**Find similar historical weeks**

```json
// Response (200)
{
  "hasSimilarWeek": true,
  "similarWeek": {
    "weekOf": "2023-11-06",
    "similarity": 0.85,
    "meetingHours": 24,
    "healthOutcome": "You slept 45 min less than usual"
  },
  "prediction": "Based on that week, watch your sleep this week"
}
```

### PUT /api/v1/health/timezone
**Update user timezone**

---

## 11. Life Insights

### GET /api/v1/insights/life
**Get AI-generated life insights (30/60 day)**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mode` | string | "30day" | "30day" or "60day" |
| `timezone` | string | America/New_York | User timezone |

```json
// Response (200)
{
  "dateRange": {"start": "2023-12-16", "end": "2024-01-15"},
  "narrative": {
    "headline": "A month of growth with some overwork patterns",
    "summary": "You've been productive but running on sleep debt...",
    "keyInsights": [...],
    "recommendations": [...]
  },
  "metrics": {
    "totalMeetingHours": 92,
    "avgDailyMeetingHours": 3.1,
    "totalFocusHours": 65
  },
  "cached": true,
  "generatedAt": "2024-01-15T10:00:00Z"
}
```

### GET /api/v1/insights/life/range
**Get life insights for custom date range**

### POST /api/v1/insights/life/regenerate
**Force regenerate insights (rate limited: 5/day)**

### DELETE /api/v1/insights/life/cache
**Clear insights cache**

### GET /api/v1/insights/life/rate-limit
**Get rate limit status**

```json
// Response (200)
{
  "remaining": 4,
  "max_per_day": 5,
  "resets_at": "2024-01-16T00:00:00"
}
```

### GET /api/v1/insights/timeline
**Get timeline aggregation (raw metrics)**

### GET /api/v1/insights/places
**Get AI place recommendations**

---

## 12. Push Notifications

### POST /push/register
**Register device token**

```json
// Request
{
  "device_token": "abc123..."
}

// Response (200)
{
  "message": "Device token registered successfully",
  "device_token": "abc123..."
}
```

### POST /push/test
**Send test notification**

### GET /api/push/status
**Get APNs status**

```json
// Response (200)
{
  "apns_ready": true,
  "device_token_registered": true,
  "device_token": "abc123..."
}
```

---

## 13. Error Handling

### Standard Error Response

```json
{
  "error": "Error type",
  "message": "Detailed error message",
  "path": "/api/endpoint"
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request - Invalid input |
| 401 | Unauthorized - Invalid/expired token |
| 403 | Forbidden - Access denied |
| 404 | Not Found |
| 429 | Too Many Requests - Rate limited |
| 500 | Internal Server Error |

### Calendar Token Expiry Response

```json
{
  "error": "token_expired",
  "provider": "google",
  "message": "Google Calendar token expired or revoked. User must reconnect.",
  "action_required": "reconnect_calendar"
}
```

---

## Additional Endpoints

### Calendars

- `GET /calendars` - List connected calendars
- `GET /calendars/diagnostics` - Connection diagnostics
- `GET /calendars/discovered` - Multi-calendar discovery
- `POST /calendars/discover/microsoft` - Discover Microsoft calendars
- `PUT /calendars/discovered/{id}/toggle` - Toggle calendar sync
- `POST /calendars/sync/microsoft/multi` - Sync all Microsoft calendars
- `POST /calendars/extract-meeting-links` - Extract meeting links from existing events

### Debug/Test

- `GET /sync/diagnostic` - Detailed sync diagnostics
- `GET /api/v1/health/debug` - Health data debug
- `POST /calendars/test-google-sync` - Test Google sync

---

## Rate Limits

| Endpoint | Limit |
|----------|-------|
| `/api/v1/insights/life/regenerate` | 5 per day |
| General API | 1000 requests/minute |

---

## Changelog

- **2024-01**: Initial API documentation
- Multi-account calendar support
- Health insights with correlation analysis
- AI-powered weekly narratives
- Pattern-based predictions

---

*Generated for AllTime Backend API v1.0*
