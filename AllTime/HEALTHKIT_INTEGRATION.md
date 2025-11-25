# HealthKit Integration Flow

## Overview

The AllTime app integrates with Apple HealthKit to read health metrics (steps, sleep, active energy, etc.) and sync them to the backend for AI-powered insights.

## Architecture

### Core Components

1. **HealthKitManager** (`AllTime/Services/HealthKitManager.swift`)
   - Manages HealthKit authorization state
   - Provides async APIs for requesting authorization and fetching health data
   - Handles per-type authorization status checking
   - **Key Fix**: Only treats integration as "denied" if ALL types are denied. If ANY type is authorized, we have access (even if partial).

2. **HealthSyncService** (`AllTime/Services/HealthSyncService.swift`)
   - Syncs health metrics to backend `POST /api/v1/health/daily`
   - Debounces sync calls (2-second interval)
   - Converts HealthKit DTOs to backend format
   - Triggers sync on app launch and foreground

3. **HealthPermissionsViewModel** (`AllTime/ViewModels/HealthPermissionsViewModel.swift`)
   - Manages UI state for Health permissions
   - Handles "Enable Health Data" button taps
   - Triggers initial sync after authorization

4. **HealthAppHelper** (`AllTime/Utils/HealthAppHelper.swift`)
   - Helper to open Health app (falls back to iOS Settings)
   - Used when permissions are denied

## Authorization Flow

### 1. Initial State Check

When the app launches or the Today/Insights screen appears:

```swift
await healthKitManager.currentAuthorizationState()
```

This calls `refreshAuthorizationState()` which:
- Checks `HKHealthStore.isHealthDataAvailable()`
- For each required type, checks `healthStore.authorizationStatus(for: type)`
- Logs per-type status (`.sharingAuthorized`, `.sharingDenied`, `.notDetermined`)
- Determines overall state:
  - **If ANY type is authorized** → `.authorized` or `.partiallyAuthorized` (we have access)
  - **If ALL types are denied** → `.denied` (no access)
  - **If any type is not determined** → `.notDetermined` (need to request)

### 2. Requesting Authorization

When user taps "Enable Health Data":

```swift
try await healthKitManager.requestAuthorization()
```

This:
- Checks current state first
- If already authorized → returns immediately and triggers sync
- If denied → throws `HealthKitError.authorizationDenied` (user must go to Health app)
- If not determined → calls `HKHealthStore.requestAuthorization(toShare:read:)`
- After authorization completes:
  - Waits 1 second for HealthKit to update internal state
  - Refreshes authorization state
  - If authorized → triggers background sync

### 3. Authorization State Logic (KEY FIX)

**Previous Bug**: The app was treating "any denial" as "all denied", even when some types were authorized.

**Fixed Logic**:
```swift
if authorizedCount > 0 {
    // We have at least one authorized type - this means we have access
    if authorizedCount == requiredTypes.count {
        authorizationState = .authorized
    } else {
        authorizationState = .partiallyAuthorized(requiredMissing: missingTypes)
    }
} else if deniedCount == requiredTypes.count {
    // ALL types are denied - this is the only case where we're truly denied
    authorizationState = .denied
} else if notDeterminedCount > 0 {
    authorizationState = .notDetermined
}
```

## Data Sync Flow

### 1. When Sync Triggers

- **On app launch**: `ContentView.initializeAppData()` calls `HealthSyncService.shared.syncRecentDays()`
- **On app foreground**: `ContentView.handleScenePhaseChange(.active)` triggers sync
- **After authorization**: `HealthKitManager.requestAuthorization()` triggers sync after 1 second delay
- **Manual trigger**: User can trigger sync via `HealthPermissionsViewModel.tapEnableHealthButton()`

### 2. Sync Process

1. Check authorization state (must have at least one authorized type)
2. Determine date range:
   - First sync: Last 14 days
   - Subsequent syncs: From last sync date to today
3. Fetch metrics from HealthKit:
   - `healthKitManager.fetchDailyMetricsForLastNDays(n)`
   - Queries run off main thread
   - Aggregates per day (midnight to midnight local time)
4. Convert DTOs to backend format:
   - Uses JSON encoding/decoding to convert `DailyHealthMetricsDTO` → `DailyHealthMetrics`
5. POST to backend:
   - `POST /api/v1/health/daily`
   - Single object or array of objects
   - Includes `Authorization: Bearer <token>` header
6. Update last sync date

### 3. Logging

Sync operations log:
- Authorization state before sync
- Date range being synced
- Number of days fetched
- Sample JSON being sent
- Number of records successfully synced
- Any errors

## UI States

### Today Screen - Health Data Card

- **`.unavailable`**: "Health data isn't available on this device."
- **`.notDetermined`**: "Enable Health Data" button → shows iOS permission dialog
- **`.denied`**: "Open Health App" button → opens Health app (falls back to Settings)
- **`.authorized` / `.partiallyAuthorized`**:
  - If synced before: Small "Health data connected ✓" row
  - If first time: "Syncing health data..." progress indicator

### Insights Screen

- Shows "No health data available" only when:
  - HealthKit is not authorized, OR
  - Backend returns null/zero health metrics for that day
- Once data is synced, shows real metrics (steps, sleep, active minutes, etc.)

## Required HealthKit Types

The app requests read access for:
- Steps (`HKQuantityType.stepCount`)
- Active Energy (`HKQuantityType.activeEnergyBurned`)
- Exercise Time (`HKQuantityType.appleExerciseTime`)
- Stand Time (`HKQuantityType.appleStandTime`)
- Resting Heart Rate (`HKQuantityType.restingHeartRate`)
- HRV (`HKQuantityType.heartRateVariabilitySDNN`)
- Sleep (`HKCategoryType.sleepAnalysis`)
- Workouts (`HKWorkoutType.workoutType()`)

## Backend API

### POST /api/v1/health/daily

**Request Body** (single object or array):
```json
{
  "date": "2025-11-16",
  "steps": 8500,
  "active_minutes": 45,
  "stand_minutes": 480,
  "active_energy_burned": 350.5,
  "resting_heart_rate": 65.0,
  "hrv": 45.2,
  "sleep_minutes": 420,
  "sleep_quality_score": 85.0,
  "workouts_count": 1
}
```

**Response**:
```json
{
  "status": "success",
  "recordsUpserted": 1
}
```

## Troubleshooting

### "All HealthKit types denied" when permissions are granted

**Cause**: Previous bug in authorization logic treated partial denial as full denial.

**Fix**: Updated `refreshAuthorizationState()` to only treat as "denied" if ALL types are denied. If ANY type is authorized, we have access.

### Health permissions not appearing in iOS Settings

**Cause**: App was installed before HealthKit capability was added.

**Solution**: Delete app, clean build folder (⇧⌘K), rebuild and reinstall.

### Sync not happening after authorization

**Check**:
1. Verify authorization state is `.authorized` or `.partiallyAuthorized` (not `.denied`)
2. Check logs for "HealthKit authorized, proceeding with sync"
3. Verify backend endpoint is accessible
4. Check network connectivity

### No health data in Insights

**Check**:
1. Verify HealthKit has actual data (open Health app)
2. Verify sync completed successfully (check logs)
3. Verify backend returned data (check API response)
4. Check Insights screen is calling `fetchHealthInsights` with correct date range

## Testing Checklist

1. ✅ Clean install → Health permissions appear in Health app
2. ✅ Tap "Enable Health Data" → iOS permission dialog appears
3. ✅ Grant permissions → Authorization state becomes `.authorized` or `.partiallyAuthorized`
4. ✅ Sync triggers automatically after authorization
5. ✅ Backend receives POST with health metrics
6. ✅ Insights screen shows real health data
7. ✅ Deny permissions → App shows "Open Health App" button
8. ✅ Partial authorization → App still works with authorized types

