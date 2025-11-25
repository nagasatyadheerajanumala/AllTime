# AI Daily Intelligence Implementation

This document describes the implementation of the new AI Daily Intelligence features in the AllTime iOS app.

## Overview

Three new v1 API endpoints have been integrated into the app:
1. **Enhanced Daily Summary** (`/api/v1/summary/daily`)
2. **Day Timeline** (`/api/v1/timeline/day`)
3. **Life Wheel Insights** (`/api/v1/insights/life-wheel`)

## Architecture

### Models

All models are located in `AllTime/Models/`:

- **EnhancedDailySummary.swift**: Contains `EnhancedDailySummaryResponse`, `HighlightItem`, `IssueItem`, `SuggestionItem`, `DayIntel`, and related nested types
- **TimelineDay.swift**: Contains `TimelineDayResponse`, `TimelineItem` (polymorphic enum), `EventItem`, `GapItem`
- **LifeWheel.swift**: Contains `LifeWheelResponse`, `ContextDistribution`

### Networking

New API methods added to `APIService` (`AllTime/Services/APIService.swift`):

- `fetchDailySummary(date: Date?) -> EnhancedDailySummaryResponse`
- `fetchDayTimeline(date: Date?) -> TimelineDayResponse`
- `fetchLifeWheel(start: Date?, end: Date?) -> LifeWheelResponse`

All methods:
- Use existing JWT Bearer token authentication
- Use the existing base URL from `Constants.API.baseURL`
- Only include date parameters if provided (backend defaults to today/7 days)
- Perform network calls off the main thread using `Task.detached`
- Include comprehensive error handling and logging

### View Models

- **EnhancedDailySummaryViewModel** (`AllTime/ViewModels/EnhancedDailySummaryViewModel.swift`):
  - Manages state for the enhanced daily summary
  - Implements caching for instant UI updates
  - Loads data off the main thread

- **TimelineDayViewModel** (in `AllTime/Views/TimelineDayView.swift`):
  - Manages timeline data for a specific day
  - Handles loading states and errors

- **LifeWheelViewModel** (in `AllTime/Views/LifeWheelView.swift`):
  - Manages life wheel insights data
  - Supports date range selection (7, 14, 30 days)

### Views

#### Enhanced Daily Summary View

**Location**: `AllTime/Views/EnhancedDailySummaryView.swift`

**Features**:
- Large overview card with second-person voice
- Key highlights section with bullet points
- Potential issues section with warning-style rows
- Suggestions section with time windows
- Day intel summary card showing aggregates
- Date selector with refresh button
- Auto-scroll to top on refresh
- Subtle animations for section appearance
- Section dividers for polished feel

**Navigation**: 
- Accessible from TodayView via "Today's AI Summary" card
- Toolbar button links to Timeline view for the selected date

#### Timeline Day View

**Location**: `AllTime/Views/TimelineDayView.swift`

**Features**:
- Chat-like feed interface showing events and gaps chronologically
- Event rows show: time, title, context badge, location, provider
- Gap rows show: free time duration with friendly message
- Uses `LazyVStack` for efficient scrolling
- Monospaced time labels for consistent alignment

**Navigation**:
- Accessible from TodayView via "See Full Day Timeline" link
- Accessible from EnhancedDailySummaryView via toolbar button

#### Life Wheel View

**Location**: `AllTime/Views/LifeWheelView.swift`

**Features**:
- Visualizes time distribution across contexts (meeting, deep work, social, health, etc.)
- Date range selector (7, 14, 30 days)
- Progress bars showing percentage of total time
- Summary card with total events
- Color-coded context cards

**Navigation**:
- Accessible from TodayView via "View Insights" link

## Navigation Integration

### TodayView Updates

**Location**: `AllTime/Views/TodayView.swift`

Added:
- "Today's AI Summary" card linking to `EnhancedDailySummaryView`
- "See Full Day Timeline" quick link
- "View Insights" quick link to `LifeWheelView`

### Quick Link Component

New `QuickLinkRow` component provides consistent styling for navigation links with icons, titles, and subtitles.

## Performance Optimizations

1. **Off-Main-Thread Network Calls**: All API calls use `Task.detached` to prevent blocking the UI
2. **Caching**: `EnhancedDailySummaryViewModel` caches recent summaries for instant display
3. **Lazy Loading**: Timeline view uses `LazyVStack` for efficient rendering of long lists
4. **View Model Pattern**: Business logic separated from views to prevent unnecessary recomputations
5. **Static Formatters**: Date and time formatters are static to prevent repeated allocation

## Error Handling

- All network errors are caught and displayed with user-friendly messages
- Retry buttons available on error states
- Graceful handling of missing/null fields in API responses
- Comprehensive logging for debugging

## Voice & Tone

- All UI text uses second-person voice ("you") as requested
- Backend-generated content already uses second-person, displayed as-is
- No "the user" language in the UI

## Testing Checklist

- [x] Enhanced Daily Summary loads for today
- [x] Enhanced Daily Summary loads for past dates
- [x] Enhanced Daily Summary handles days with no events
- [x] Timeline view displays events and gaps correctly
- [x] Timeline view handles empty days
- [x] Life Wheel displays distribution correctly
- [x] Life Wheel date range selector works
- [x] Navigation links work from TodayView
- [x] Error states show friendly messages
- [x] Retry functionality works
- [x] No crashes when fields are missing/null

## Future Enhancements

Potential improvements:
- Add push notification support for daily summary
- Add widget support for quick summary view
- Add export/share functionality for insights
- Add more detailed analytics in Life Wheel view
- Add filtering options in Timeline view

