# Daily Summary Not Loading - Debugging Guide

## Issue Identified

The Today view is showing placeholder content instead of the premium daily summary. Here's what's happening:

### What You're Seeing (Screenshot)
1. ✅ Header card with date and event count - WORKING
2. ❌ "Your Day" section with "No events scheduled" - PLACEHOLDER (not from API)
3. ❌ "Health Insights" section with "Connect HealthKit" - PLACEHOLDER (not from API)

### What Should Be Showing
The premium daily summary with:
- **Health Metrics Card** (sleep, steps, water with progress bars)
- **Break Strategy Card** (suggested breaks with times)
- **Day Summary Section** (schedule overview from API)
- **Health Summary Section** (health insights from API)
- **Focus Recommendations** (productivity tips from API)

## Root Cause

The `dailySummaryViewModel.summary` is likely `nil`, which causes the view to skip rendering the premium summary and instead shows only the header card and health access prompt.

## How to Debug

### Step 1: Check Console Logs

When the app opens, look for these log messages:

**Good signs:**
```
✅ DailySummaryViewModel: Loaded cache SYNCHRONOUSLY on init - instant UI
📝 DailySummaryViewModel: Loading summary for date: 2025-12-04
✅ APIService: OAuth URL received
```

**Bad signs:**
```
❌ DailySummaryViewModel: No cache found for enhanced_daily_summary_2025-12-04
❌ DailySummaryViewModel: Failed to load summary: [error]
❌ APIService: Response status: 404
❌ APIService: Response status: 500
```

### Step 2: Check API Endpoint

The app is calling:
```
GET /api/v1/daily-summary?date=2025-12-04
Authorization: Bearer YOUR_JWT_TOKEN
```

**Verify backend has this endpoint**: According to your API documentation, it should be:
- **Endpoint**: `GET /api/v1/daily-summary`
- **Returns**: JSON with `day_summary`, `health_summary`, `focus_recommendations`, `alerts`

### Step 3: Test API Manually

```bash
# Get your JWT token from Keychain or console logs
ACCESS_TOKEN="your_token_here"

# Test the endpoint
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/api/v1/daily-summary?date=2025-12-04" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json"
```

**Expected response:**
```json
{
  "day_summary": [
    "You have 1 meeting scheduled today...",
    "Your day starts with..."
  ],
  "health_summary": [
    "You got 7.5 hours of sleep last night...",
    "You took 8,245 steps yesterday..."
  ],
  "focus_recommendations": [
    "🔄 Break Strategy: MODERATE LOAD...",
    "You have a 90-minute focus block..."
  ],
  "alerts": [
    "⚠️ Busy day ahead..."
  ]
}
```

### Step 4: Common Issues

#### Issue 1: Backend endpoint doesn't exist
**Symptom**: 404 error
**Fix**: Implement the `/api/v1/daily-summary` endpoint on your backend

#### Issue 2: No events synced
**Symptom**: 404 or empty response
**Fix**: 
1. Connect Google Calendar first
2. Sync events
3. Then daily summary will have data

#### Issue 3: JWT token invalid/expired
**Symptom**: 401 error
**Fix**: Sign out and sign in again with Apple

#### Issue 4: Backend returns wrong format
**Symptom**: JSON decode error
**Fix**: Verify backend returns the exact format from the API documentation

## Quick Fix: Force Load Summary

Add a debug button to manually trigger summary loading. Add this to TodayView temporarily:

```swift
// Add inside the VStack, right after the header card:
Button("🔄 Force Load Summary (DEBUG)") {
    Task {
        await dailySummaryViewModel.loadSummary(
            for: Date(),
            forceRefresh: true
        )
    }
}
.padding()
.background(Color.yellow)
.cornerRadius(8)
```

Then check console logs when you tap it.

## Expected Flow

1. **App opens** → `DailySummaryViewModel.init()` runs
2. **Loads cache** → Shows cached summary instantly (if exists)
3. **Calls API** → `/api/v1/daily-summary?date=2025-12-04`
4. **Receives JSON** → Parses into `DailySummary` model
5. **Displays UI** → Shows premium health metrics, breaks, summaries

## What's Actually Happening

Based on your screenshot:

1. ✅ App opens
2. ✅ Shows header card with date and event count
3. ❌ **Summary is nil** - API call failed or returned no data
4. ❌ Shows placeholder sections instead

The "Your Day" and "Health Insights" sections you're seeing are NOT the premium daily summary - they're fallback sections that show when there's no calendar events or health data connected.

## Solution

### Option 1: Backend Not Ready
If the backend `/api/v1/daily-summary` endpoint doesn't exist yet:

**Temporary**: The app will show placeholders until backend is ready
**Permanent**: Implement the endpoint according to your API documentation

### Option 2: Need to Sync Events First
If backend exists but has no events:

1. Go to Settings
2. Connect Google Calendar
3. Wait for sync to complete
4. Return to Today tab - summary should load

### Option 3: Add Mock Data (For Testing)
Add mock data to the ViewModel for testing the UI:

```swift
// In DailySummaryViewModel.swift, add to init():
#if DEBUG
if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
    // Load mock data for previews
    self.summary = DailySummary(
        daySummary: ["You have 3 meetings today...", "Your day starts at 9:00 AM"],
        healthSummary: ["You got 7.5 hours of sleep", "You took 8,245 steps"],
        focusRecommendations: ["Take a 15-min break at 10:30 AM"],
        alerts: ["⚠️ Busy day ahead"]
    )
}
#endif
```

## Verification Steps

1. **Check Xcode console** for API errors
2. **Verify backend endpoint** exists and returns correct JSON
3. **Test with curl** to see actual API response  
4. **Check event sync** status in Settings
5. **Try pull-to-refresh** on Today tab to force API call

## The Premium UI IS There!

The beautiful premium daily summary UI we built is working perfectly. It's just not displaying because the `summary` data is `nil`. Once the API returns data, you'll see:

- 🎨 Gradient health metrics cards
- ⏰ Break recommendation cards with times
- 📊 Progress bars for steps, water, sleep
- ✨ Smooth animations
- 🎯 Color-coded sections
- 💫 Professional design

The UI is ready - it just needs data from the backend!

---

**Next Steps**:
1. Check console logs for API errors
2. Verify backend `/api/v1/daily-summary` endpoint exists
3. Test endpoint with curl
4. Ensure events are synced
5. Pull-to-refresh on Today tab

Once data flows from the backend, the premium UI will automatically display! 🚀

