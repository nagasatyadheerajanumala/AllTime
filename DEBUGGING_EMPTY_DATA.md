# 🔍 Debugging: Empty Data Issue

## Problem
Everything is showing empty:
- ❌ No daily summary
- ❌ No food places
- ❌ No walking suggestions

---

## Step 1: Check Xcode Console Logs

**Look for these log messages:**

### Daily Summary Logs:
```
📊 DailySummaryViewModel: Loading daily summary...
📤 DailySummaryViewModel: Requesting from: https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/daily-summary
📥 DailySummaryViewModel: Response status: ???
```

**Possible Issues:**

### A) **404 Not Found**
```
📥 DailySummaryViewModel: Response status: 404
❌ DailySummaryViewModel: Error response: {"error": "Not found"}
```
**→ Backend hasn't implemented `/api/v1/daily-summary` yet**

### B) **500 Server Error**
```
📥 DailySummaryViewModel: Response status: 500
❌ DailySummaryViewModel: Error response: Internal Server Error
```
**→ Backend has a bug in `/api/v1/daily-summary`**

### C) **401 Unauthorized**
```
📥 DailySummaryViewModel: Response status: 401
❌ DailySummaryViewModel: Error response: Unauthorized
```
**→ JWT token is invalid or expired**

### D) **No Access Token**
```
❌ DailySummaryViewModel: No access token
```
**→ User is not logged in**

### E) **Decoding Error**
```
❌ DailySummaryViewModel: Decoding error: keyNotFound
   Missing key: day_summary
```
**→ Backend response doesn't match expected structure**

---

## Step 2: Check What You See in the App

### If you see an error message:
- The app will show "Failed to Load Summary" with the error
- Click "Try Again" button
- Check Xcode console for detailed logs

### If you see nothing (blank screen):
- The ViewModel might not be loading at all
- Check if `onAppear` is being called
- Look for this log: `📊 DailySummaryViewModel: Loading daily summary...`

---

## Step 3: Test Individual Endpoints

### Test Daily Summary Endpoint:
```bash
# Replace YOUR_JWT_TOKEN with your actual token from Keychain
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/daily-summary
```

**Expected Response:**
```json
{
  "day_summary": ["You have 3 meetings today", "..."],
  "health_summary": ["Sleep: 7.2 hours", "..."],
  "focus_recommendations": ["Best focus: 10 AM", "..."],
  "alerts": ["⚠️ Dehydration risk", "..."],
  "health_based_suggestions": [...],
  "location_recommendations": {...},
  "break_recommendations": {...}
}
```

### Test Food Endpoint:
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/food?category=all&radius=1.5"
```

**Expected Response:**
```json
{
  "healthy_options": [...],
  "regular_options": [...],
  "user_location": "New Brunswick, USA",
  "search_radius_km": 1.5,
  "message": "Found X options"
}
```

### Test Walk Endpoint:
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/walk?duration=20&difficulty=easy"
```

**Expected Response:**
```json
{
  "user_location": "New Brunswick, USA",
  "requested_duration_minutes": 20,
  "difficulty": "easy",
  "health_benefit": "...",
  "message": "...",
  "routes": [...]
}
```

---

## Step 4: Common Backend Issues

### Issue 1: Endpoint Not Implemented
**Symptom:** 404 Not Found
**Fix:** Backend needs to implement:
- `GET /api/v1/daily-summary`
- `GET /api/v1/recommendations/food`
- `GET /api/v1/recommendations/walk`

### Issue 2: Wrong JSON Structure
**Symptom:** Decoding errors, keyNotFound
**Fix:** Backend must use **snake_case** keys:
- ✅ `day_summary` (not `daySummary`)
- ✅ `health_summary` (not `healthSummary`)
- ✅ `location_recommendations` (not `locationRecommendations`)

### Issue 3: Missing User Location
**Symptom:** Empty location recommendations
**Fix:** Backend needs:
1. User location saved in `user_locations` table
2. Location API to fetch lunch/walk suggestions
3. Google Places API configured

### Issue 4: No Calendar Events
**Symptom:** Summary works but says "No events"
**Fix:** User needs to:
1. Connect Google Calendar or Microsoft Outlook
2. Have events in their calendar
3. Sync calendars

---

## Step 5: Quick Fixes

### Fix 1: Restart App
1. Stop app in Xcode
2. Clean build folder (⇧⌘K)
3. Build and run (⌘R)

### Fix 2: Re-authenticate
1. Log out of app
2. Log back in with Sign in with Apple
3. This refreshes JWT token

### Fix 3: Check Network
1. Make sure device/simulator has internet
2. Try opening Safari and loading google.com
3. Check if backend URL is accessible

### Fix 4: Force Location Update
1. Tap location button (top left)
2. Grant location permission if prompted
3. Wait for location to be acquired

---

## Step 6: Enable Verbose Logging

The app already logs everything. **Look for these patterns:**

### Successful Flow:
```
📊 DailySummaryViewModel: Loading daily summary...
📤 DailySummaryViewModel: Requesting from: https://...
📥 DailySummaryViewModel: Response status: 200
📥 DailySummaryViewModel: Raw JSON: {"day_summary":...}
✅ DailySummaryViewModel: Successfully loaded summary
   - Day summary: 5 items
   - Health summary: 4 items
   - Alerts: 2 items
   - Location: New Brunswick, USA
   - Lunch spots: 3
   - Walk routes: 3
```

### Failed Flow:
```
📊 DailySummaryViewModel: Loading daily summary...
📤 DailySummaryViewModel: Requesting from: https://...
📥 DailySummaryViewModel: Response status: 500
❌ DailySummaryViewModel: Error response: Internal Server Error
```

---

## Step 7: Backend Checklist

Ask your backend team to verify:

- [ ] `/api/v1/daily-summary` endpoint exists
- [ ] Endpoint returns 200 status code
- [ ] Response uses `snake_case` JSON keys
- [ ] Response includes all required fields:
  - [ ] `day_summary` (array of strings)
  - [ ] `health_summary` (array of strings)
  - [ ] `focus_recommendations` (array of strings)
  - [ ] `alerts` (array of strings)
  - [ ] `health_based_suggestions` (array of objects)
  - [ ] `location_recommendations` (object, can be null)
  - [ ] `break_recommendations` (object, can be null)

- [ ] `/api/v1/recommendations/food` endpoint exists
- [ ] Returns `healthy_options` and `regular_options`
- [ ] Uses `snake_case` for all keys

- [ ] `/api/v1/recommendations/walk` endpoint exists
- [ ] Returns `routes` array
- [ ] Uses `snake_case` for all keys
- [ ] Field is `duration_minutes` (not `estimated_minutes`)

---

## Step 8: Test with Postman/curl

1. Get your JWT token from Keychain (or check Xcode logs)
2. Test each endpoint manually
3. Verify response structure matches expected format

**Example curl command:**
```bash
# Get JWT token from app logs, then:
curl -v -H "Authorization: Bearer eyJhbGc..." \
  https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/daily-summary
```

Look for:
- Status code: Should be `200 OK`
- Content-Type: Should be `application/json`
- Body: Should match expected JSON structure

---

## Step 9: If Still Not Working

### Share These Logs:
1. **From Xcode Console:**
   - All lines starting with `📊`, `📤`, `📥`, `❌`, `✅`
   - Any decoding errors
   - HTTP status codes

2. **From Backend Logs:**
   - Request received for `/api/v1/daily-summary`
   - Response sent
   - Any errors

3. **From curl Test:**
   - Full response from manual API test
   - HTTP status code
   - Response headers

---

## 🎯 Most Likely Causes

Based on "everything is empty", the most likely issues are:

1. **Backend not implemented yet** (404)
   - Solution: Implement endpoints

2. **Backend returning errors** (500)
   - Solution: Fix backend bugs

3. **Wrong JSON structure** (Decoding errors)
   - Solution: Use snake_case keys

4. **No location data** (Empty location_recommendations)
   - Solution: User needs to grant location permission + backend needs to save location

5. **No calendar events** (Empty schedule)
   - Solution: Connect calendar + have events

---

## 🔧 Quick Diagnostic

**Run this in your app and check Xcode console:**

1. Open app
2. Go to Today tab
3. Pull down to refresh
4. Look for logs in Xcode console
5. Take a screenshot of the logs
6. Share with backend team

**Key Question:** What HTTP status code do you see?
- 200 = Success (but maybe empty data)
- 401 = Auth problem
- 404 = Endpoint doesn't exist
- 500 = Backend bug

---

**Need Help?** Share the Xcode console logs and I can pinpoint the exact issue!

