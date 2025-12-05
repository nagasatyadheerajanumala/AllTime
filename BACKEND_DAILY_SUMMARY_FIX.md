# Backend Daily Summary Endpoint - Error Fix Guide

## Issue Summary

The iOS app is calling `/api/v1/daily-summary` but receiving a 500 Internal Server Error. The endpoint exists but is crashing during execution.

---

## Current Error

**Request:**
```
GET /api/v1/daily-summary?date=2025-12-04
Authorization: Bearer <jwt_token>
```

**Response:**
```json
HTTP 500 Internal Server Error

{
  "path": "/api/v1/daily-summary",
  "error": "Internal server error",
  "message": "An unexpected error occurred",
  "timestamp": "2025-12-05T00:34:37.478764525"
}
```

---

## Expected Response Format

The endpoint MUST return this exact JSON structure:

```json
{
  "day_summary": [
    "You have 6 meetings scheduled today, totaling 240 minutes (4.0 hours)",
    "Your day starts with \"Team Standup\" at 9:00 AM",
    "Key meetings today:",
    "  • Sprint Planning at 10:00 AM (90 minutes)"
  ],
  "health_summary": [
    "You got 7.5 hours of sleep last night, right on track with your average of 7.5 hours",
    "You took 8,245 steps yesterday - 1,755 short of your 10,000 step goal",
    "You had 45 active minutes yesterday - exceeded your goal by 15 minutes!",
    "You drank 1.8 liters of water yesterday - 0.7 liters below your goal",
    "💧 With 6 meetings today (4.0 hours), aim to drink at least 1.5 liters of water",
    "Your resting heart rate is 62 BPM, stable and consistent with your baseline"
  ],
  "focus_recommendations": [
    "🔄 Break Strategy: MODERATE LOAD: Busy day ahead - take at least one 5-minute break every hour",
    "🔔 MEAL: 45-min meal break at 12:30 PM - No clear lunch break detected",
    "🔔 MOVEMENT: 20-min movement break at 10:00 AM - Yesterday's step count was low",
    "You have a 90-minute focus block from 2:00 PM to 3:30 PM - perfect for deep work"
  ],
  "alerts": [
    "⚠️ Sleep deficit: You got 6.5 hours last night vs your average of 8.0 hours",
    "💧 Water intake low: You're 0.7 liters below your daily water goal",
    "⚠️ Steps goal not met: You're 1,755 steps short of your daily goal"
  ]
}
```

### Response Field Requirements

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `day_summary` | `string[]` | Yes | Meeting and calendar summary (can be empty array) |
| `health_summary` | `string[]` | Yes | Health metrics summary (can be empty array) |
| `focus_recommendations` | `string[]` | Yes | Break suggestions and focus blocks (can be empty array) |
| `alerts` | `string[]` | Yes | Health and productivity warnings (can be empty array) |

**Important:** All fields are **required**. Return empty arrays `[]` if no data available, never `null` or omit fields.

---

## How to Debug

### 1. Check Backend Logs

**For Cloud Run (GCP):**
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=alltime-backend" \
  --limit 50 \
  --format json \
  | grep -A 10 "/api/v1/daily-summary"
```

**For local development:**
Check your console output for stack traces when the endpoint is called.

### 2. Test Endpoint Directly

```bash
# Replace YOUR_JWT_TOKEN with actual token
curl -v \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://alltime-backend-756952284083.us-central1.run.app/api/v1/daily-summary?date=2025-12-04"
```

### 3. Common Issues to Check

#### Issue #1: Missing Route Handler
**Check:** Does the endpoint exist in your routes?

```javascript
// routes/api.js or similar
router.get('/api/v1/daily-summary', authenticate, getDailySummary);
```

#### Issue #2: Database Query Errors
**Check:** Are you handling missing data gracefully?

```javascript
// ❌ BAD - Will crash if no data
const healthMetrics = await db.query('SELECT * FROM health_metrics WHERE user_id = $1', [userId]);
const steps = healthMetrics.rows[0].steps; // Crashes if no rows

// ✅ GOOD - Safe handling
const healthMetrics = await db.query('SELECT * FROM health_metrics WHERE user_id = $1', [userId]);
const steps = healthMetrics.rows[0]?.steps || 0;
```

#### Issue #3: Missing Calendar Events
**Check:** Handle case when user has no events for the date

```javascript
// ❌ BAD
const events = await getEventsForDate(userId, date);
const firstEvent = events[0].title; // Crashes if no events

// ✅ GOOD
const events = await getEventsForDate(userId, date);
if (events.length === 0) {
  return {
    day_summary: ["No events scheduled for this day"],
    health_summary: [],
    focus_recommendations: [],
    alerts: []
  };
}
```

#### Issue #4: Unhandled Async Errors
**Check:** Wrap async operations in try-catch

```javascript
// ❌ BAD
async function getDailySummary(req, res) {
  const data = await generateSummary(userId, date); // No error handling
  res.json(data);
}

// ✅ GOOD
async function getDailySummary(req, res) {
  try {
    const data = await generateSummary(userId, date);
    res.json(data);
  } catch (error) {
    console.error('Daily summary error:', error);
    res.status(500).json({
      path: req.path,
      error: 'Internal server error',
      message: error.message, // Include actual error for debugging
      timestamp: new Date().toISOString()
    });
  }
}
```

#### Issue #5: LLM/AI Service Errors
**Check:** Handle OpenAI or other AI service failures

```javascript
// If using OpenAI to generate summaries
try {
  const aiSummary = await openai.chat.completions.create({...});
} catch (error) {
  console.error('OpenAI error:', error);
  // Return basic summary without AI enhancement
  return generateBasicSummary(events, healthData);
}
```

---

## Minimum Working Implementation

Here's a basic implementation that will work with the iOS app:

```javascript
const express = require('express');
const router = express.Router();

// GET /api/v1/daily-summary
router.get('/api/v1/daily-summary', authenticate, async (req, res) => {
  try {
    const userId = req.user.id;
    const date = req.query.date || new Date().toISOString().split('T')[0];

    console.log(`Generating daily summary for user ${userId}, date ${date}`);

    // 1. Fetch calendar events (handle if none exist)
    let events = [];
    try {
      events = await getCalendarEvents(userId, date);
    } catch (error) {
      console.error('Error fetching events:', error);
      // Continue with empty events
    }

    // 2. Fetch health metrics (handle if none exist)
    let healthMetrics = null;
    try {
      healthMetrics = await getHealthMetrics(userId, date);
    } catch (error) {
      console.error('Error fetching health metrics:', error);
      // Continue with null health metrics
    }

    // 3. Generate summary sections
    const daySummary = generateDaySummary(events);
    const healthSummary = generateHealthSummary(healthMetrics);
    const focusRecommendations = generateFocusRecommendations(events, healthMetrics);
    const alerts = generateAlerts(healthMetrics);

    // 4. Return response (all fields required)
    res.json({
      day_summary: daySummary,
      health_summary: healthSummary,
      focus_recommendations: focusRecommendations,
      alerts: alerts
    });

  } catch (error) {
    console.error('Daily summary error:', error);
    console.error('Stack trace:', error.stack);

    res.status(500).json({
      path: req.path,
      error: 'Internal server error',
      message: error.message, // Include actual error message for debugging
      timestamp: new Date().toISOString()
    });
  }
});

// Helper functions
function generateDaySummary(events) {
  if (!events || events.length === 0) {
    return ["No events scheduled for this day"];
  }

  const summary = [];
  summary.push(`You have ${events.length} meetings scheduled today`);

  const firstEvent = events[0];
  summary.push(`Your day starts with "${firstEvent.title}" at ${formatTime(firstEvent.start)}`);

  return summary;
}

function generateHealthSummary(healthMetrics) {
  if (!healthMetrics) {
    return ["No health data available for this day"];
  }

  const summary = [];

  if (healthMetrics.sleep_hours) {
    summary.push(`You got ${healthMetrics.sleep_hours} hours of sleep last night`);
  }

  if (healthMetrics.steps) {
    summary.push(`You took ${healthMetrics.steps.toLocaleString()} steps yesterday`);
  }

  if (healthMetrics.water_intake_liters) {
    summary.push(`You drank ${healthMetrics.water_intake_liters} liters of water yesterday`);
  }

  return summary;
}

function generateFocusRecommendations(events, healthMetrics) {
  const recommendations = [];

  // Add break strategy based on meeting count
  if (events && events.length > 5) {
    recommendations.push("🔄 Break Strategy: BUSY DAY: Take a 5-minute break every hour");
  } else if (events && events.length > 2) {
    recommendations.push("🔄 Break Strategy: MODERATE LOAD: Take breaks between meetings");
  }

  // Add hydration reminder if many meetings
  if (events && events.length > 3) {
    recommendations.push("🔔 HYDRATION: 15-min water break at 3:00 PM - Stay hydrated during meetings");
  }

  return recommendations;
}

function generateAlerts(healthMetrics) {
  const alerts = [];

  if (healthMetrics?.sleep_hours && healthMetrics.sleep_hours < 7) {
    alerts.push(`⚠️ Sleep deficit: You got ${healthMetrics.sleep_hours} hours last night`);
  }

  if (healthMetrics?.water_intake_liters && healthMetrics.water_intake_liters < 2.0) {
    const deficit = (2.5 - healthMetrics.water_intake_liters).toFixed(1);
    alerts.push(`💧 Water intake low: You're ${deficit} liters below your daily water goal`);
  }

  if (healthMetrics?.steps && healthMetrics.steps < 10000) {
    const deficit = 10000 - healthMetrics.steps;
    alerts.push(`⚠️ Steps goal not met: You're ${deficit.toLocaleString()} steps short of your daily goal`);
  }

  return alerts;
}

module.exports = router;
```

---

## Testing Checklist

Once you've fixed the endpoint, test these scenarios:

### ✅ Basic Response
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://your-backend.com/api/v1/daily-summary?date=2025-12-04"

# Should return 200 with all 4 fields (day_summary, health_summary, focus_recommendations, alerts)
```

### ✅ No Events
```bash
# Test with a date that has no calendar events
curl -H "Authorization: Bearer TOKEN" \
  "https://your-backend.com/api/v1/daily-summary?date=2020-01-01"

# Should return 200 with empty arrays, NOT 500 error
```

### ✅ No Health Data
```bash
# Test with a user who hasn't synced health data
# Should return 200 with empty health_summary, NOT crash
```

### ✅ Missing Date Parameter
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://your-backend.com/api/v1/daily-summary"

# Should default to today's date
```

### ✅ Invalid Date Format
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://your-backend.com/api/v1/daily-summary?date=invalid"

# Should return 400 Bad Request with error message
```

---

## iOS Parser Details

The iOS app uses `SummaryParser` to extract structured data from the string arrays:

### What the Parser Looks For:

1. **In `health_summary`:**
   - Sleep hours: `"(\d+\.?\d*) hours? of sleep"`
   - Steps: `"(\d{1,3}(?:,\d{3})*) steps"`
   - Water intake: `"(\d+\.?\d*) liters? of water"`
   - Active minutes: `"(\d+) active minutes"`

2. **In `focus_recommendations`:**
   - Break strategy: Lines starting with `"🔄 Break Strategy:"`
   - Break windows: Lines starting with `"🔔"` followed by type (MEAL, HYDRATION, MOVEMENT, REST, PREP)
   - Format: `"🔔 TYPE: duration-min break at HH:MM AM/PM - reasoning"`

3. **In `alerts`:**
   - Severity: Checks for `"🚨"` (critical), `"⚠️"` (warning), or treats as info
   - Category: Detects keywords like "sleep", "water", "hydration", "step", "stress"

### Example Parsed Output:

**Input:**
```json
{
  "health_summary": [
    "You got 7.5 hours of sleep last night",
    "You took 8,245 steps yesterday - 1,755 short of your 10,000 step goal",
    "You drank 1.8 liters of water yesterday - 0.7 liters below your goal"
  ],
  "focus_recommendations": [
    "🔄 Break Strategy: MODERATE LOAD: Busy day ahead",
    "🔔 MEAL: 45-min meal break at 12:30 PM - No clear lunch break detected"
  ],
  "alerts": [
    "⚠️ Sleep deficit: You got 6.5 hours last night"
  ]
}
```

**Parsed to:**
- Sleep hours: `7.5`
- Steps: `8245`, Goal: `10000`
- Water intake: `1.8L`, Goal: `2.5L`
- Break strategy: `"MODERATE LOAD: Busy day ahead"`
- Break window: Meal break at 12:30 PM for 45 min
- Alert: Warning severity, sleep category

---

## Success Criteria

The endpoint is fixed when:

✅ Returns HTTP 200 status
✅ Includes all 4 required fields in response
✅ Each field is an array of strings
✅ No crashes when data is missing
✅ No crashes when events don't exist
✅ Works with current date and historical dates
✅ iOS app displays the summary without errors

---

## Contact

If you need clarification on the expected format or have questions about what the iOS app needs, please share:

1. Your current endpoint implementation code
2. The full error stack trace from backend logs
3. Sample health metrics and events data structure

This will help diagnose the exact issue.

---

**Last Updated:** December 4, 2025
**iOS Implementation Status:** ✅ Complete and Ready
**Backend Status:** ❌ Needs Fix (500 Error)
