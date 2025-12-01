# Backend Cursor Agent: December 1st Events Not Returned

## Problem Statement

The iOS frontend is requesting events for December 1st, 2025, but the backend is not returning any events for that date, even though:
- The date range request includes December 1st
- Events exist on other December dates (Dec 2, 9, 16, 23, 24, 30)
- The frontend date filtering logic is working correctly

## Frontend Request Details

### API Endpoint
`GET /events` or `GET /calendars/events/upcoming`

### Request Parameters
- **startDate**: `2024-11-01T00:00:00Z` (or calculated as today - 30 days)
- **endDate**: `2025-12-31T23:59:59Z` (or calculated as max(selectedDate + 30 days, today + 60 days))
- **period**: `"custom"`
- **autoSync**: `false`

### Expected Behavior
The backend should return all events within the date range, including events on December 1st, 2025 if they exist in the user's connected calendars (Google Calendar, Microsoft Outlook).

## Diagnostic Information

### Events Returned
- **Total events**: 124 events
- **Date range**: December 24, 2024 to December 30, 2025
- **December 2025 events**: 7 events found
  - December 2, 2025: 1 event
  - December 9, 2025: 1 event
  - December 16, 2025: 1 event
  - December 23, 2025: 2 events
  - December 24, 2025: 1 event
  - December 30, 2025: 1 event
- **December 1, 2025**: 0 events ❌

### Frontend Verification
- Date normalization: ✅ Working correctly
- Index lookup: ✅ Date found in index
- Index entry: Empty array (0 events)
- Date range calculation: ✅ Includes December 1st

## Possible Root Causes

### 1. Date Range Query Issue
The SQL query or database filter might be excluding December 1st due to:
- **Time component handling**: Events might be stored with time components that cause them to be filtered out
- **Timezone conversion**: UTC vs local timezone conversion might cause date boundary issues
- **Inclusive/exclusive range**: The query might use `>= startDate AND < endDate` instead of `>= startDate AND <= endDate`

### 2. Event Storage Issue
Events on December 1st might not be synced from Google/Microsoft Calendar:
- **Sync date range**: The sync process might not be fetching events for December 1st
- **Event filtering**: Some filter might be excluding events on that specific date
- **Recurring events**: Recurring events might not be expanded correctly for December 1st

### 3. Calendar Provider Issue
The source calendars (Google/Microsoft) might not have events on December 1st, but this should be verified.

## Required Investigation

### Step 1: Verify Database Query
**Location**: Event fetching endpoint (likely `GET /events` or similar)

**Check**:
1. What SQL query is being executed?
2. Are date comparisons using `>=` and `<=` (inclusive) or `>` and `<` (exclusive)?
3. How are time components handled in the date comparison?
4. Is timezone conversion applied correctly?

**Example problematic query**:
```sql
-- BAD: Might exclude events on the exact start date
SELECT * FROM events 
WHERE start_time >= :startDate 
  AND start_time < :endDate

-- GOOD: Should include events on both start and end dates
SELECT * FROM events 
WHERE start_time >= :startDate 
  AND start_time <= :endDate
```

### Step 2: Check Event Storage
**Location**: Database events table

**Query to run**:
```sql
-- Check if any events exist for December 1st, 2025
SELECT id, title, start_time, end_time, source, user_id
FROM events
WHERE DATE(start_time) = '2025-12-01'
  AND user_id = :userId
ORDER BY start_time;

-- Check events around December 1st (Dec 30 - Dec 2)
SELECT id, title, start_time, end_time, source, user_id
FROM events
WHERE start_time >= '2025-11-30 00:00:00'
  AND start_time <= '2025-12-02 23:59:59'
  AND user_id = :userId
ORDER BY start_time;
```

### Step 3: Verify Calendar Sync
**Location**: Calendar sync service (Google Calendar sync, Microsoft sync)

**Check**:
1. What date range is being requested from Google/Microsoft Calendar API?
2. Are events on December 1st being returned by the provider API?
3. Are events on December 1st being filtered out during sync?
4. Is the sync process correctly handling timezone conversions?

**Google Calendar API check**:
```python
# Verify what Google Calendar returns
events_result = service.events().list(
    calendarId='primary',
    timeMin='2025-12-01T00:00:00Z',
    timeMax='2025-12-01T23:59:59Z',
    singleEvents=True,
    orderBy='startTime'
).execute()
```

### Step 4: Check Timezone Handling
**Location**: Date parsing and storage logic

**Check**:
1. How are event start times stored in the database? (UTC or local time?)
2. How are date range parameters parsed? (UTC or local time?)
3. Are timezone conversions applied consistently?

**Common issue**:
- Events stored in UTC: `2025-12-01 05:00:00 UTC` (which is Dec 1st 00:00 EST)
- Query uses local time: `2025-12-01 00:00:00 EST`
- Mismatch causes events to be excluded

## Expected Fixes

### Fix 1: Ensure Inclusive Date Range
**File**: Event fetching endpoint/service

**Change**:
```python
# Before (might exclude boundary dates)
events = db.query(Event).filter(
    Event.start_time >= start_date,
    Event.start_time < end_date  # Exclusive - excludes end_date
).all()

# After (includes boundary dates)
events = db.query(Event).filter(
    Event.start_time >= start_date,
    Event.start_time <= end_date  # Inclusive - includes end_date
).all()
```

### Fix 2: Normalize Dates to Start of Day
**File**: Date range calculation

**Change**:
```python
# Normalize start_date to beginning of day (00:00:00)
start_date = start_date.replace(hour=0, minute=0, second=0, microsecond=0)

# Normalize end_date to end of day (23:59:59)
end_date = end_date.replace(hour=23, minute=59, second=59, microsecond=999999)
```

### Fix 3: Handle Timezone Consistently
**File**: Date parsing and query logic

**Change**:
```python
# Ensure all dates are in UTC for database queries
from datetime import timezone

start_date_utc = start_date.astimezone(timezone.utc) if start_date.tzinfo else start_date.replace(tzinfo=timezone.utc)
end_date_utc = end_date.astimezone(timezone.utc) if end_date.tzinfo else end_date.replace(tzinfo=timezone.utc)

# Query using UTC dates
events = db.query(Event).filter(
    Event.start_time >= start_date_utc,
    Event.start_time <= end_date_utc
).all()
```

## Testing Checklist

After implementing fixes:

- [ ] **Query returns December 1st events**:
  ```sql
  SELECT COUNT(*) FROM events 
  WHERE DATE(start_time) = '2025-12-01' AND user_id = :test_user_id;
  ```
  Should return > 0 if events exist

- [ ] **API endpoint includes December 1st**:
  ```bash
  curl -X GET "https://api.example.com/events?startDate=2025-11-01&endDate=2025-12-31" \
    -H "Authorization: Bearer $TOKEN"
  ```
  Response should include events with `start_time` on 2025-12-01

- [ ] **Date range boundaries work**:
  - Test with `startDate = endDate = 2025-12-01`
  - Should return events on that exact date

- [ ] **Timezone handling works**:
  - Test with different timezone offsets
  - Events should be returned regardless of user's timezone

## Additional Notes

### Frontend Confirmation
The frontend has been verified to:
- ✅ Correctly normalize dates to start of day
- ✅ Use proper date range calculations
- ✅ Handle timezone conversions correctly
- ✅ Index events by normalized dates

The issue is confirmed to be on the backend side - either in the query logic, event storage, or calendar sync process.

### Priority
**HIGH** - This affects user experience when viewing specific dates. Users expect to see all events for a selected date if they exist in their calendars.

## Success Criteria

After the fix:
1. ✅ Events on December 1st, 2025 are returned if they exist in the user's calendars
2. ✅ Date range queries include boundary dates (start and end dates)
3. ✅ Timezone conversions are handled consistently
4. ✅ All events within the requested date range are returned

## Files to Investigate

1. **Event fetching endpoint**: `GET /events` or `GET /calendars/events/upcoming`
2. **Event repository/service**: Database query logic
3. **Calendar sync service**: Google Calendar and Microsoft sync logic
4. **Date utility functions**: Timezone conversion and date normalization

## Quick Debug Query

Run this to check if events exist for December 1st:

```sql
-- Check all events around December 1st, 2025
SELECT 
    id,
    title,
    start_time,
    end_time,
    DATE(start_time) as event_date,
    source,
    user_id
FROM events
WHERE start_time >= '2025-11-30 00:00:00'
  AND start_time < '2025-12-02 00:00:00'
ORDER BY start_time;
```

If this query returns events on December 1st but the API doesn't, the issue is in the API query logic.
If this query doesn't return events on December 1st, the issue is in the calendar sync process.

