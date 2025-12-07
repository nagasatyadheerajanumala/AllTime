# Backend Implementation Requirements - Complete Specification

**For Backend Claude Agent: Please implement these 3 endpoints exactly as specified**

---

# 🎯 Overview

You need to implement 3 endpoints for the iOS calendar app:

1. **Daily Summary** - Auto-generated summary when user opens Today tab
2. **Food Recommendations** - On-demand food suggestions (healthy + regular)
3. **Walk Recommendations** - On-demand walk routes (distance-based)

**Base URL:** `https://alltime-backend-hicsfvfd7q-uc.a.run.app`

**Authentication:** All endpoints require JWT Bearer token

---

# 📊 API 1: Daily Summary (CRITICAL - Currently Broken!)

## Endpoint

```
GET /api/v1/daily-summary
```

## Current Problem

**The endpoint exists and returns 200, but ALL arrays are EMPTY:**

```json
{
  "alerts": [],
  "health_summary": [],
  "health_based_suggestions": [],
  "focus_recommendations": [],
  "day_summary": []
}
```

**This is WRONG!** User has calendar events, so arrays should have data!

---

## Required Response Structure

```json
{
  "day_summary": [
    "You have {count} meetings today ({hours} hours total)",
    "First meeting: {event_title} at {time}",
    "Last meeting ends at {time}",
    "Busiest period: {time_range}",
    "{lunch_info}"
  ],
  
  "health_summary": [
    "Sleep last night: {hours} hours (vs. your {avg} hour average)",
    "Steps yesterday: {count} (vs. {goal} goal) - {percentage}% of goal",
    "Water intake yesterday: {liters}L (vs. {goal}L goal)",
    "Resting heart rate: {bpm} bpm",
    "Active minutes: {minutes} min (vs. {goal} min goal)"
  ],
  
  "focus_recommendations": [
    "Best focus window: {start_time} - {end_time}",
    "Schedule deep work during {time_of_day}",
    "You have {duration}-minute focus block from {start} to {end}"
  ],
  
  "alerts": [
    "⚠️ DEHYDRATION RISK: Only {liters}L water yesterday (goal: {goal}L)",
    "⚠️ Sleep deficit: {minutes} minutes below baseline",
    "⚠️ Meeting clash at {time}"
  ],
  
  "health_based_suggestions": [
    {
      "type": "hydration",
      "priority": "high",
      "message": "Drink water now - you're {percentage}% below YOUR {goal}L goal",
      "action": "Drink 500ml before your next meeting",
      "timestamp": "2025-12-05T09:00:00"
    },
    {
      "type": "movement",
      "priority": "medium",
      "message": "Take a walk during your free block to reach step goal",
      "action": "20-minute walk recommended (adds ~2,000 steps)",
      "timestamp": "2025-12-05T15:30:00"
    }
  ],
  
  "location_recommendations": {
    "user_city": "New Brunswick",
    "user_country": "USA",
    "latitude": 40.4862,
    "longitude": -74.4518,
    
    "lunch_recommendation": {
      "recommendation_time": "12:30 PM",
      "minutes_until_lunch": 195,
      "message": "Lunch break in 3 hours 15 minutes at 12:30 PM",
      "nearby_spots": [
        {
          "name": "Sweetgreen",
          "address": "123 George St, New Brunswick, NJ",
          "distance_km": 0.3,
          "walking_minutes": 4,
          "rating": 4.7,
          "price_level": "$$",
          "cuisine": "Salad",
          "open_now": true,
          "photo_url": "https://maps.googleapis.com/..."
        }
      ]
    },
    
    "walk_routes": [
      {
        "name": "Buccleuch Park Loop",
        "description": "Scenic walk through local park",
        "distance_km": 1.5,
        "duration_minutes": 20,
        "difficulty": "easy",
        "route_type": "park",
        "waypoints": [
          {
            "latitude": 40.4862,
            "longitude": -74.4518,
            "name": "Start"
          }
        ],
        "map_url": "https://www.google.com/maps/dir/?api=1&..."
      }
    ],
    
    "lunch_message": "Found 5 lunch options near New Brunswick",
    "walk_message": "Found 3 walk routes near New Brunswick"
  },
  
  "break_recommendations": {
    "strategy": "regular_breaks",
    "suggested_breaks": [
      {
        "type": "Hydration",
        "start_time": "10:30 AM",
        "duration_minutes": 5,
        "reason": "Stay hydrated between meetings"
      },
      {
        "type": "Meal",
        "start_time": "12:30 PM",
        "duration_minutes": 45,
        "reason": "Lunch break - nearby options available"
      }
    ],
    "minutes_until_lunch": 195
  }
}
```

## Field Requirements

| Field | Type | Required? | Can Be Empty? | Can Be Null? |
|-------|------|-----------|---------------|--------------|
| `day_summary` | Array | ✅ YES | ✅ YES | ❌ NO |
| `health_summary` | Array | ✅ YES | ✅ YES | ❌ NO |
| `focus_recommendations` | Array | ✅ YES | ✅ YES | ❌ NO |
| `alerts` | Array | ✅ YES | ✅ YES | ❌ NO |
| `health_based_suggestions` | Array | ✅ YES | ✅ YES | ❌ NO |
| `location_recommendations` | Object | ✅ YES | N/A | ✅ YES |
| `break_recommendations` | Object | ✅ YES | N/A | ✅ YES |

**CRITICAL:** All 7 fields must ALWAYS be present in the response!

---

## Implementation Requirements

### 1. Generate Day Summary

**Input:** User ID, today's date

**Logic:**
```java
List<Event> events = getEventsForToday(userId);

List<String> daySummary = new ArrayList<>();

if (events.isEmpty()) {
    daySummary.add("No meetings scheduled for today");
    daySummary.add("Great day for focused work!");
} else {
    int totalMinutes = events.stream().mapToInt(e -> e.getDurationMinutes()).sum();
    double hours = totalMinutes / 60.0;
    
    daySummary.add(String.format("You have %d meetings today (%.1f hours total)", 
        events.size(), hours));
    
    Event firstEvent = events.get(0);
    daySummary.add(String.format("First meeting: %s at %s", 
        firstEvent.getTitle(), formatTime(firstEvent.getStartTime())));
    
    Event lastEvent = events.get(events.size() - 1);
    daySummary.add(String.format("Last meeting ends at %s", 
        formatTime(lastEvent.getEndTime())));
    
    // Add busiest period info
    // Add lunch break info if detected
}

return daySummary;
```

### 2. Generate Health Summary

**Input:** User ID

**Logic:**
```java
HealthMetrics metrics = getYesterdayHealthMetrics(userId);

List<String> healthSummary = new ArrayList<>();

if (metrics == null) {
    healthSummary.add("Connect your health data to see personalized insights");
    return healthSummary;
}

if (metrics.getSleepHours() != null) {
    double userAvg = getUserAverageSleep(userId);
    healthSummary.add(String.format("Sleep last night: %.1f hours (vs. your %.1f hour average)", 
        metrics.getSleepHours(), userAvg));
}

if (metrics.getSteps() != null) {
    int goal = getUserStepGoal(userId);
    int percentage = (metrics.getSteps() * 100) / goal;
    healthSummary.add(String.format("Steps yesterday: %d (vs. %d goal) - %d%% of goal", 
        metrics.getSteps(), goal, percentage));
}

if (metrics.getWaterIntake() != null) {
    double goal = getUserWaterGoal(userId);
    healthSummary.add(String.format("Water intake yesterday: %.1fL (vs. %.1fL goal)%s", 
        metrics.getWaterIntake(), goal, 
        metrics.getWaterIntake() < goal * 0.7 ? " - DEHYDRATION RISK" : ""));
}

return healthSummary;
```

### 3. Generate Focus Recommendations

**Input:** User ID, today's events

**Logic:**
```java
List<Event> events = getEventsForToday(userId);
List<String> focusRecs = new ArrayList<>();

// Find longest free block
FreeBlock longestBlock = findLongestFreeBlock(events);

if (longestBlock != null && longestBlock.getDurationMinutes() >= 60) {
    focusRecs.add(String.format("Best focus window: %s - %s (%d-hour block)",
        formatTime(longestBlock.getStart()),
        formatTime(longestBlock.getEnd()),
        longestBlock.getDurationMinutes() / 60));
}

// Break strategy based on meeting load
int meetingHours = calculateTotalMeetingHours(events);
if (meetingHours >= 6) {
    focusRecs.add("🔄 Break Strategy: HEAVY LOAD: Take a 5-minute break every 30 minutes");
} else if (meetingHours >= 3) {
    focusRecs.add("🔄 Break Strategy: MODERATE LOAD: Take a 5-minute break every hour");
} else {
    focusRecs.add("🔄 Break Strategy: LIGHT DAY: Take breaks as needed");
}

// Hydration recommendation
focusRecs.add(String.format("💧 With %d meetings today (%.1f hours), aim to drink at least %.1f liters of water",
    events.size(), meetingHours, meetingHours * 0.35));

return focusRecs;
```

---

# 🍽️ API 2: Food Recommendations (On-Demand)

## Endpoint

```
GET /api/v1/recommendations/food
```

## Query Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `radius` | Double | 1.5 | 0.5-5.0 | Search radius in **kilometers** |
| `category` | String | "all" | - | "healthy", "regular", or "all" |
| `max_results` | Integer | 10 | 1-50 | Maximum results to return |

## Required Response Structure

```json
{
  "healthyOptions": [
    {
      "name": "Sweetgreen",
      "address": "123 George St, New Brunswick, NJ",
      "distanceKm": 0.3,
      "walkingMinutes": 4,
      "rating": 4.7,
      "priceLevel": "$$",
      "cuisine": "Salad",
      "openNow": true,
      "photoUrl": "https://maps.googleapis.com/...",
      "categories": ["healthy", "organic"],
      "healthScore": "excellent",
      "dietaryTags": ["vegan", "gluten-free"]
    }
  ],
  
  "regularOptions": [
    {
      "name": "Stuff Yer Face",
      "address": "789 Easton Ave, New Brunswick, NJ",
      "distanceKm": 0.4,
      "walkingMinutes": 5,
      "rating": 4.6,
      "priceLevel": "$",
      "cuisine": "Pizza",
      "openNow": true,
      "photoUrl": null,
      "categories": ["restaurant"],
      "healthScore": "indulgent",
      "dietaryTags": []
    }
  ],
  
  "userLocation": "New Brunswick, USA",
  "searchRadiusKm": 1.5,
  "message": "Found 2 healthy and 1 regular options near you"
}
```

**CRITICAL:** Use **camelCase** for all JSON keys (NOT snake_case)!

## Implementation Requirements

### 1. Get User Location

```java
UserLocation location = userLocationRepo.findByUserId(userId);

if (location == null) {
    return ResponseEntity.ok(Map.of(
        "healthyOptions", List.of(),
        "regularOptions", List.of(),
        "userLocation", "Unknown",
        "searchRadiusKm", radius,
        "message", "Enable location services to see nearby options"
    ));
}
```

### 2. Fetch Nearby Places (Google Places API)

```java
String apiKey = System.getenv("GOOGLE_PLACES_API_KEY");
String placesUrl = String.format(
    "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=%f,%f&radius=%d&type=restaurant&key=%s",
    location.getLatitude(),
    location.getLongitude(),
    (int)(radiusKm * 1000),  // Convert km to meters
    apiKey
);

// Fetch results from Google Places
List<PlaceResult> places = fetchFromGooglePlaces(placesUrl);
```

### 3. Categorize as Healthy vs Regular

```java
List<FoodSpot> healthy = new ArrayList<>();
List<FoodSpot> regular = new ArrayList<>();

for (PlaceResult place : places) {
    FoodSpot spot = convertToFoodSpot(place, location);
    
    if (isHealthy(place)) {
        healthy.add(spot);
    } else {
        regular.add(spot);
    }
}

// Apply category filter
if ("healthy".equals(category)) {
    regular.clear();
} else if ("regular".equals(category)) {
    healthy.clear();
}

// Limit results
healthy = healthy.stream().limit(maxResults / 2).collect(Collectors.toList());
regular = regular.stream().limit(maxResults / 2).collect(Collectors.toList());
```

### 4. Determine if Healthy

```java
private boolean isHealthy(PlaceResult place) {
    String types = place.getTypes().stream().collect(Collectors.joining(",")).toLowerCase();
    String name = place.getName().toLowerCase();
    
    // Healthy indicators
    if (types.contains("health") || types.contains("salad") || types.contains("juice")) return true;
    if (name.contains("salad") || name.contains("smoothie") || name.contains("juice")) return true;
    if (name.contains("vegan") || name.contains("organic") || name.contains("fresh")) return true;
    
    // Unhealthy indicators (exclude)
    if (types.contains("pizza") || types.contains("burger") || types.contains("fast_food")) return false;
    
    // Default: check rating and price
    return place.getRating() >= 4.0 && !"$".equals(place.getPriceLevel());
}
```

### 5. Convert to FoodSpot

```java
private FoodSpot convertToFoodSpot(PlaceResult place, UserLocation userLocation) {
    // Calculate distance
    double distanceKm = calculateDistance(
        userLocation.getLatitude(), userLocation.getLongitude(),
        place.getGeometry().getLocation().getLat(),
        place.getGeometry().getLocation().getLng()
    );
    
    // Calculate walking time (avg speed: 5 km/h)
    int walkingMinutes = (int) Math.ceil((distanceKm / 5.0) * 60);
    
    // Get photo URL
    String photoUrl = null;
    if (place.getPhotos() != null && !place.getPhotos().isEmpty()) {
        String photoRef = place.getPhotos().get(0).getPhotoReference();
        photoUrl = String.format(
            "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=%s&key=%s",
            photoRef, googleApiKey
        );
    }
    
    return FoodSpot.builder()
        .name(place.getName())
        .address(place.getVicinity())
        .distanceKm(distanceKm)
        .walkingMinutes(walkingMinutes)
        .rating(place.getRating())
        .priceLevel(convertPriceLevel(place.getPriceLevel()))
        .cuisine(getCuisineType(place))
        .openNow(place.getOpeningHours() != null && place.getOpeningHours().isOpenNow())
        .photoUrl(photoUrl)
        .categories(determineCategories(place))
        .healthScore(calculateHealthScore(place))
        .dietaryTags(extractDietaryTags(place))
        .build();
}
```

**CRITICAL:** Return response with **camelCase keys**:
```java
Map<String, Object> response = new HashMap<>();
response.put("healthyOptions", healthy);      // camelCase!
response.put("regularOptions", regular);      // camelCase!
response.put("userLocation", location.getCity() + ", " + location.getCountry());
response.put("searchRadiusKm", radiusKm);     // camelCase!
response.put("message", String.format("Found %d healthy and %d regular options near you", 
    healthy.size(), regular.size()));

return ResponseEntity.ok(response);
```

---

# 🚶 API 3: Walk Recommendations (On-Demand)

## Endpoint

```
GET /api/v1/recommendations/walk
```

## Query Parameters

| Parameter | Type | Default | Range | Description |
|-----------|------|---------|-------|-------------|
| `distance_miles` | Double | - | 0.5-3.0 | Walk distance in **MILES** (preferred) |
| `duration` | Integer | 20 | 10-60 | Walk duration in **minutes** (fallback) |
| `difficulty` | String | "easy" | - | "easy", "moderate", "challenging", or "all" |

**CRITICAL:** Support BOTH `distance_miles` AND `duration` parameters!

## Distance Conversion

```java
// If user provides distance_miles:
if (distanceMiles != null) {
    durationMinutes = (int) (distanceMiles * 20);  // 3 mph = 20 min/mile
    distanceKm = distanceMiles * 1.60934;
}
// Else if user provides duration:
else if (duration != null) {
    durationMinutes = duration;
    distanceKm = (duration / 60.0) * 5.0;  // 5 km/h walking speed
    distanceMiles = distanceKm * 0.621371;
}
```

**Distance Reference Table:**

| Miles | Minutes (3 mph) | Kilometers |
|-------|-----------------|------------|
| 0.5 | 10 | 0.8 |
| 1.0 | 20 | 1.6 |
| 1.5 | 30 | 2.4 |
| 2.0 | 40 | 3.2 |
| 2.5 | 50 | 4.0 |
| 3.0 | 60 | 4.8 |

## Required Response Structure

```json
{
  "userLocation": "New Brunswick, United States",
  "requestedDurationMinutes": 20,
  "difficulty": "easy",
  "healthBenefit": "A 20-minute walk burns ~100 calories and counts toward your daily activity goal",
  "message": "Found 3 walk routes for 20 minutes (1.7 km) near New Brunswick",
  
  "routes": [
    {
      "name": "Park Walk: Donaldson Park",
      "description": "Enjoy green space and fresh air at Donaldson Park",
      "distanceKm": 1.67,
      "estimatedMinutes": 20,
      "difficulty": "easy",
      "routeType": "park",
      "waypoints": [
        {
          "latitude": 40.4862,
          "longitude": -74.4518,
          "name": "Start",
          "description": null
        },
        {
          "latitude": 40.4925,
          "longitude": -74.4462,
          "name": "Donaldson Park",
          "description": null
        },
        {
          "latitude": 40.4862,
          "longitude": -74.4518,
          "name": "Return",
          "description": null
        }
      ],
      "mapUrl": "https://www.google.com/maps/dir/?api=1&origin=40.4862,-74.4518&destination=40.4925,-74.4462&travelmode=walking",
      "highlights": ["Green space", "Fresh air", "Nature", "Peaceful"],
      "elevationGain": 0.0,
      "wheelchairAccessible": true,
      "bestTimeOfDay": "anytime"
    },
    {
      "name": "Neighborhood Loop",
      "description": "Explore your local area on foot",
      "distanceKm": 1.67,
      "estimatedMinutes": 20,
      "difficulty": "easy",
      "routeType": "neighborhood",
      "waypoints": [
        {
          "latitude": 40.4862,
          "longitude": -74.4518,
          "name": "Start/End",
          "description": null
        }
      ],
      "mapUrl": "https://www.google.com/maps/@40.4862,-74.4518,15z",
      "highlights": ["Local area", "Flexible", "Safe", "Convenient"],
      "elevationGain": 0.0,
      "wheelchairAccessible": true,
      "bestTimeOfDay": "anytime"
    },
    {
      "name": "Urban Discovery",
      "description": "Discover your city's streets and shops",
      "distanceKm": 1.67,
      "estimatedMinutes": 20,
      "difficulty": "easy",
      "routeType": "urban",
      "waypoints": [
        {
          "latitude": 40.4862,
          "longitude": -74.4518,
          "name": "Start/End",
          "description": null
        }
      ],
      "mapUrl": "https://www.google.com/maps/@40.4862,-74.4518,16z",
      "highlights": ["City life", "Window shopping", "People watching", "Cafes"],
      "elevationGain": 0.0,
      "wheelchairAccessible": true,
      "bestTimeOfDay": "afternoon"
    }
  ]
}
```

**CRITICAL:** Use **camelCase** for all JSON keys (NOT snake_case)!

## Implementation Requirements

### 1. Get User Location

```java
UserLocation location = userLocationRepo.findByUserId(userId);

if (location == null) {
    return ResponseEntity.ok(Map.of(
        "userLocation", "Unknown",
        "requestedDurationMinutes", durationMinutes,
        "difficulty", difficulty,
        "healthBenefit", calculateHealthBenefit(durationMinutes),
        "message", "Enable location services to see walk routes",
        "routes", List.of()
    ));
}
```

### 2. Generate Walk Routes

```java
List<WalkRoute> routes = new ArrayList<>();

// Route 1: Find nearest park (if within radius)
Park nearestPark = findNearestPark(location, distanceKm);
if (nearestPark != null) {
    routes.add(generateParkRoute(location, nearestPark, distanceKm, durationMinutes));
}

// Route 2: Neighborhood loop (always available)
routes.add(generateNeighborhoodLoop(location, distanceKm, durationMinutes));

// Route 3: Urban discovery (if in city area)
if (isUrbanArea(location)) {
    routes.add(generateUrbanRoute(location, distanceKm, durationMinutes));
}

// Filter by difficulty
if (!"all".equals(difficulty)) {
    routes = routes.stream()
        .filter(r -> difficulty.equals(r.getDifficulty()))
        .collect(Collectors.toList());
}

return routes;
```

### 3. Generate Park Route

```java
private WalkRoute generateParkRoute(UserLocation location, Park park, double distanceKm, int durationMinutes) {
    List<Waypoint> waypoints = new ArrayList<>();
    waypoints.add(new Waypoint(location.getLatitude(), location.getLongitude(), "Start", null));
    waypoints.add(new Waypoint(park.getLatitude(), park.getLongitude(), park.getName(), null));
    waypoints.add(new Waypoint(location.getLatitude(), location.getLongitude(), "Return", null));
    
    String mapUrl = String.format(
        "https://www.google.com/maps/dir/?api=1&origin=%f,%f&destination=%f,%f&travelmode=walking",
        location.getLatitude(), location.getLongitude(),
        park.getLatitude(), park.getLongitude()
    );
    
    return WalkRoute.builder()
        .name("Park Walk: " + park.getName())
        .description("Enjoy green space and fresh air at " + park.getName())
        .distanceKm(distanceKm)
        .estimatedMinutes(durationMinutes)
        .difficulty("easy")
        .routeType("park")
        .waypoints(waypoints)
        .mapUrl(mapUrl)
        .highlights(List.of("Green space", "Fresh air", "Nature", "Peaceful"))
        .elevationGain(0.0)
        .wheelchairAccessible(true)
        .bestTimeOfDay("anytime")
        .build();
}
```

### 4. Calculate Health Benefit

```java
private String calculateHealthBenefit(int durationMinutes) {
    int calories = durationMinutes * 5;  // Rough estimate: 5 cal/min
    
    if (durationMinutes >= 30) {
        return String.format("A %d-minute walk burns ~%d calories and significantly boosts your daily activity", 
            durationMinutes, calories);
    } else {
        return String.format("A quick %d-minute walk to boost circulation and energy", 
            durationMinutes);
    }
}
```

**CRITICAL:** Return response with **camelCase keys**:
```java
Map<String, Object> response = new HashMap<>();
response.put("userLocation", location.getCity() + ", " + location.getCountry());
response.put("requestedDurationMinutes", durationMinutes);  // camelCase!
response.put("difficulty", difficulty);
response.put("healthBenefit", healthBenefit);               // camelCase!
response.put("message", message);
response.put("routes", routes);

return ResponseEntity.ok(response);
```

---

# 🎯 Key Differences Between APIs

| Aspect | Daily Summary | Food Recommendations | Walk Recommendations |
|--------|---------------|---------------------|---------------------|
| **JSON Format** | snake_case | camelCase | camelCase |
| **Trigger** | Automatic | On-demand (user taps) | On-demand (user taps) |
| **Complexity** | High (7 fields) | Medium (categorization) | High (route generation) |
| **Caching** | Yes (5 min) | Yes (10 min) | Yes (10 min) |
| **Google API** | No | Yes (Places) | Yes (Places + Directions) |

---

# 🔧 Critical Implementation Notes

## 1. JSON Key Format

**DIFFERENT for each API:**

### Daily Summary (snake_case):
```json
{
  "day_summary": [],           // snake_case
  "health_summary": [],        // snake_case
  "focus_recommendations": []  // snake_case
}
```

### Food & Walk (camelCase):
```json
{
  "healthyOptions": [],        // camelCase
  "userLocation": "",          // camelCase
  "searchRadiusKm": 1.5        // camelCase
}
```

## 2. Distance Units

**Food API:**
- Input: `radius` in **kilometers**
- Response: `distanceKm` in kilometers
- iOS displays in miles for UI

**Walk API:**
- Input: `distance_miles` in **miles** (preferred)
- OR `duration` in minutes (fallback)
- Response: `distanceKm` in kilometers + `estimatedMinutes`

## 3. Error Handling

**All endpoints must:**
- Return 200 even if no data (empty arrays, not null!)
- Handle missing user location gracefully
- Never return 500 errors
- Log all errors for debugging

---

# 🚨 Current Critical Bug

## Daily Summary Endpoint

**Current Response:**
```json
{
  "day_summary": [],        // ❌ EMPTY (but user has 2 events!)
  "health_summary": [],     // ❌ EMPTY
  "focus_recommendations": [], // ❌ EMPTY
  "alerts": [],
  "health_based_suggestions": [],
  "location_recommendations": null,
  "break_recommendations": null
}
```

**Expected Response:**
```json
{
  "day_summary": [
    "You have 2 meetings today (2 hours total)",
    "First meeting: Testing 1 location details at 12:00 PM",
    "Last meeting ends at 2:00 PM"
  ],
  "health_summary": [
    "Connect your health data to see personalized insights"
  ],
  "focus_recommendations": [
    "Light day ahead - good for focused work",
    "💧 With 2 meetings (2 hours), drink at least 0.7 liters of water"
  ],
  "alerts": [],
  "health_based_suggestions": [],
  "location_recommendations": {
    "user_city": "New Brunswick",
    "user_country": "USA",
    "latitude": 40.4862,
    "longitude": -74.4518,
    "lunch_recommendation": {
      "recommendation_time": "12:00 PM",
      "minutes_until_lunch": 0,
      "message": "Lunch time now!",
      "nearby_spots": [...]
    },
    "walk_routes": [...]
  },
  "break_recommendations": null
}
```

**YOU BROKE THE DATA GENERATION!** 🚨

---

# ✅ What You Need to Fix

## Priority 1: Daily Summary Data Generation (URGENT!)

**The Problem:**
```java
// CURRENT (BROKEN):
response.put("day_summary", List.of());  // ❌ Empty array!
```

**The Fix:**
```java
// FIXED:
List<String> daySummary = generateDaySummary(userId);  // ✅ Call actual generation!
response.put("day_summary", daySummary);
```

**Do this for:**
- `day_summary` - Generate from calendar events
- `health_summary` - Generate from health metrics
- `focus_recommendations` - Generate based on schedule
- `alerts` - Generate based on health risks
- `health_based_suggestions` - Generate personalized tips

## Priority 2: Ensure All 7 Fields Present

```java
// Template for correct implementation:
Map<String, Object> response = new HashMap<>();

// Generate data (DON'T use empty arrays!)
response.put("day_summary", generateDaySummary(userId));
response.put("health_summary", generateHealthSummary(userId));
response.put("focus_recommendations", generateFocusRecommendations(userId));
response.put("alerts", generateAlerts(userId));
response.put("health_based_suggestions", generateHealthSuggestions(userId));
response.put("location_recommendations", getLocationRecommendations(userId));  // Can be null
response.put("break_recommendations", getBreakRecommendations(userId));        // Can be null

return ResponseEntity.ok(response);
```

## Priority 3: Food & Walk APIs (Working but Verify)

- ✅ Food API works (returns data)
- ✅ Walk API works (returns routes)
- ⚠️ Verify camelCase format

---

# 🧪 Testing Checklist

After you fix the backend:

### Daily Summary:
```bash
curl "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/daily-summary" \
  -H "Authorization: Bearer TOKEN"

# Should return:
# - day_summary: Array with event info (NOT empty!)
# - health_summary: Array with health data or fallback message
# - focus_recommendations: Array with tips
# - All 7 fields present
```

### Food Recommendations:
```bash
curl "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/food?category=all&radius=1.5" \
  -H "Authorization: Bearer TOKEN"

# Should return:
# - healthyOptions: Array (camelCase!)
# - regularOptions: Array (camelCase!)
```

### Walk Recommendations:
```bash
curl "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/v1/recommendations/walk?distance_miles=1.0&difficulty=easy" \
  -H "Authorization: Bearer TOKEN"

# Should return:
# - routes: Array with 3 routes
# - estimatedMinutes: Based on distance
# - All camelCase keys
```

---

# 📝 Summary for Backend Agent

## Your Tasks:

1. **FIX DAILY SUMMARY** (CRITICAL!)
   - Currently returning all empty arrays
   - Need to call data generation methods
   - User has 2 events but seeing nothing!

2. **Verify Food API** (Working but check)
   - Should return camelCase keys
   - Categorize healthy vs regular
   - Use Google Places API

3. **Verify Walk API** (Working but check)
   - Support `distance_miles` parameter
   - Return camelCase keys
   - Generate 3 route types (park, neighborhood, urban)

## Data Format Requirements:

- **Daily Summary:** snake_case keys (day_summary, health_summary)
- **Food & Walk:** camelCase keys (healthyOptions, userLocation)

## Response Guarantees:

- **Arrays:** Never null, can be empty
- **Objects:** Can be null
- **All 7 fields:** Must be present in daily summary

---

**FIX URGENTLY: Daily summary is completely broken - returning empty arrays instead of real data!** 🚨

