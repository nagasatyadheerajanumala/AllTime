# 🔧 Backend Issues - Found from Logs

## ✅ **Daily Summary - PARTIALLY WORKING!**

### Status: **200 OK** - But missing fields

The `/api/v1/daily-summary` endpoint IS working and returning data, but it's **incomplete**.

### What's Working ✅
```json
{
  "alerts": [],
  "health_summary": ["Enhanced health summary temporarily unavailable..."],
  "focus_recommendations": ["Break Strategy...", "..."],
  "day_summary": ["You have 4 meetings...", "..."]
}
```

### What's Missing ❌
```json
{
  "health_based_suggestions": [],  // ← MISSING!
  "location_recommendations": {     // ← MISSING!
    "user_city": "New Brunswick",
    "lunch_recommendation": {...},
    "walk_routes": [...]
  },
  "break_recommendations": {...}    // ← MISSING!
}
```

### Fix Required:
Backend must include these fields in the response (can be empty arrays/null):

```python
# In your backend daily summary endpoint:
response = {
    "day_summary": [...],
    "health_summary": [...],
    "focus_recommendations": [...],
    "alerts": [...],
    "health_based_suggestions": [],  # ADD THIS (can be empty)
    "location_recommendations": None,  # ADD THIS (or populate with data)
    "break_recommendations": None  # ADD THIS (or populate with data)
}
```

---

## ❌ **Walk Recommendations - FAILING (500 Error)**

### Status: **500 Internal Server Error**

```
📥 OnDemandAPI: Walk response: 500
❌ ViewModel: Failed to load walk recommendations: serverError
```

### Endpoint:
```
GET /api/v1/recommendations/walk?distance_miles=1.0&difficulty=easy
```

### Issue:
Backend is **crashing** when this endpoint is called.

### Likely Causes:
1. **No user location in database**
   - Check if `user_locations` table has an entry for this user
   - Run: `SELECT * FROM user_locations WHERE user_id = ?`

2. **Missing Google Places API key**
   - Check if `GOOGLE_PLACES_API_KEY` is set in environment

3. **Backend bug in walk route generation**
   - Check backend logs for stack trace
   - Look for errors in the walk route calculation logic

### Debug Steps:
```bash
# Test manually with curl:
curl -v -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/walk?distance_miles=1.0&difficulty=easy"

# Check backend logs:
gcloud logs read --project=YOUR_PROJECT --limit=50 | grep -A 20 "walk"
```

---

## ❌ **Food Recommendations - LIKELY FAILING**

### Status: **Probably 500 Error** (same as walk)

### Endpoint:
```
GET /api/v1/recommendations/food?category=all&radius=1.5
```

### Issue:
User mentioned "same scenario for food places" - likely also returning 500.

### Same Fixes as Walk:
1. Ensure user location exists in database
2. Verify Google Places API key is configured
3. Check backend logs for errors

---

## 🎯 **Summary of Backend Issues**

| Endpoint | Status | Issue | Fix Priority |
|----------|--------|-------|--------------|
| `/api/v1/daily-summary` | ⚠️ 200 | Missing fields | **HIGH** - Add missing fields |
| `/api/v1/recommendations/walk` | ❌ 500 | Backend crash | **CRITICAL** - Fix crash |
| `/api/v1/recommendations/food` | ❌ 500 | Backend crash | **CRITICAL** - Fix crash |

---

## 🔧 **Required Backend Fixes**

### 1. Daily Summary Endpoint (HIGH PRIORITY)

Add these fields to the response:

```python
def get_daily_summary(user_id):
    # ... existing code ...
    
    response = {
        "day_summary": day_summary_array,
        "health_summary": health_summary_array,
        "focus_recommendations": focus_recommendations_array,
        "alerts": alerts_array,
        
        # ADD THESE:
        "health_based_suggestions": [],  # Populate or leave empty
        "location_recommendations": get_location_recommendations(user_id),  # Or None
        "break_recommendations": get_break_recommendations(user_id)  # Or None
    }
    
    return response
```

### 2. Walk Recommendations Endpoint (CRITICAL)

Fix the 500 error:

```python
def get_walk_recommendations(user_id, distance_miles, difficulty):
    try:
        # Get user location
        location = db.query(UserLocation).filter_by(user_id=user_id).first()
        if not location:
            return {
                "user_location": "Unknown",
                "requested_duration_minutes": int(distance_miles * 20),
                "difficulty": difficulty,
                "health_benefit": f"A {int(distance_miles * 20)}-minute walk burns ~{int(distance_miles * 100)} calories",
                "message": "Location not available. Please enable location services.",
                "routes": []
            }
        
        # Generate routes based on distance_miles
        routes = generate_walk_routes(
            latitude=location.latitude,
            longitude=location.longitude,
            distance_miles=distance_miles,
            difficulty=difficulty
        )
        
        return {
            "user_location": f"{location.city}, {location.country}",
            "requested_duration_minutes": int(distance_miles * 20),  # 3 mph = 20 min/mile
            "difficulty": difficulty,
            "health_benefit": f"A {int(distance_miles * 20)}-minute walk burns ~{int(distance_miles * 100)} calories",
            "message": f"Found {len(routes)} routes for {distance_miles} miles",
            "routes": routes
        }
        
    except Exception as e:
        logger.error(f"Walk recommendations error: {str(e)}")
        raise  # This is causing the 500
```

### 3. Food Recommendations Endpoint (CRITICAL)

Same pattern as walk:

```python
def get_food_recommendations(user_id, category, radius):
    try:
        # Get user location
        location = db.query(UserLocation).filter_by(user_id=user_id).first()
        if not location:
            return {
                "healthy_options": [],
                "regular_options": [],
                "user_location": "Unknown",
                "search_radius_km": radius,
                "message": "Location not available. Please enable location services."
            }
        
        # Fetch nearby restaurants using Google Places API
        places = fetch_nearby_places(
            latitude=location.latitude,
            longitude=location.longitude,
            radius_km=radius,
            category=category
        )
        
        # Categorize as healthy or regular
        healthy = [p for p in places if is_healthy(p)]
        regular = [p for p in places if not is_healthy(p)]
        
        return {
            "healthy_options": healthy,
            "regular_options": regular,
            "user_location": f"{location.city}, {location.country}",
            "search_radius_km": radius,
            "message": f"Found {len(healthy)} healthy and {len(regular)} regular options"
        }
        
    except Exception as e:
        logger.error(f"Food recommendations error: {str(e)}")
        raise  # This is causing the 500
```

---

## 🧪 **Testing After Fixes**

### 1. Test Daily Summary:
```bash
curl -H "Authorization: Bearer TOKEN" \
  https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/daily-summary

# Should return ALL fields including:
# - health_based_suggestions (can be [])
# - location_recommendations (can be null)
# - break_recommendations (can be null)
```

### 2. Test Walk Recommendations:
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/walk?distance_miles=1.0&difficulty=easy"

# Should return 200 with routes array
```

### 3. Test Food Recommendations:
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/food?category=all&radius=1.5"

# Should return 200 with healthy_options and regular_options
```

---

## ✅ **iOS App Status**

The iOS app is **ready** and will work as soon as the backend fixes these issues:

1. ✅ Models support optional fields
2. ✅ Error handling in place
3. ✅ Logging shows exact backend responses
4. ✅ UI components ready to display data
5. ✅ Distance conversion (miles/km) implemented

**Once backend is fixed, everything will work!** 🚀

---

## 🎯 **Quick Win**

The **easiest fix** to see something working:

### Fix Daily Summary Response:
Just add these three lines to your backend:

```python
response["health_based_suggestions"] = []
response["location_recommendations"] = None
response["break_recommendations"] = None
```

This will make the daily summary work immediately! ✅

