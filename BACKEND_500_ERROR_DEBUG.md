# 🚨 Backend 500 Error - AI Summary Generation Debug Guide

**Date:** December 7, 2025
**Error:** Internal server error at `/api/daily-summary/generate`
**Response Time:** 0.07s (very fast = crashed before reaching OpenAI)
**Status:** Backend endpoint exists but crashes immediately

---

## ⚠️ Error Details

### iOS App Logs
```
🤖 APIService: ===== GENERATING AI DAILY SUMMARY =====
🤖 APIService: URL: https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/daily-summary/generate?date=2025-12-06&timezone=America/New_York
🤖 APIService: Date: 2025-12-06
🤖 APIService: Timezone: America/New_York
🤖 APIService: Note: This may take 3-10 seconds (OpenAI processing)

🤖 APIService: Response status: 500
🤖 APIService: Generation took: 0.07s  ⚠️ TOO FAST - CRASHED BEFORE OPENAI

❌ APIService: ===== SERVER ERROR (500) =====
❌ APIService: AI generation failed - backend may return fallback summary
❌ APIService: Full response: {
  "path": "/api/daily-summary/generate",
  "error": "Internal server error",
  "message": "An unexpected error occurred",
  "timestamp": "2025-12-07T02:22:29.270041457"
}
```

### 🔍 Key Observation
**Response time: 0.07 seconds**

This is **WAY too fast** for OpenAI processing (should be 3-10 seconds). The backend is crashing **immediately** before even making the OpenAI API call.

---

## 🔎 Root Cause Analysis

### Most Likely Causes (in order):

1. **Missing OpenAI API Key** ❌
   - Backend tries to access `process.env.OPENAI_API_KEY`
   - Variable not set in Cloud Run environment
   - Code crashes when initializing OpenAI client

2. **Database Query Error** ❌
   - Fetching user data, events, or health metrics
   - Missing required fields in database
   - Timezone conversion issue

3. **Missing Dependencies** ❌
   - OpenAI library not installed
   - `npm install` didn't include openai package
   - Import statement fails

4. **Data Validation Error** ❌
   - Date parsing fails
   - Timezone string invalid
   - Missing user in database

---

## 🛠️ Debugging Steps for Backend Team

### Step 1: Check Backend Logs

**For Google Cloud Run:**
```bash
gcloud logging read \
  "resource.type=cloud_run_revision AND resource.labels.service_name=alltime-backend" \
  --limit 100 \
  --format json \
  | jq -r '.[] | select(.textPayload | contains("/api/daily-summary/generate")) | .textPayload'
```

**Look for:**
- Stack traces
- "Cannot read property" errors
- "undefined" errors
- OpenAI-related errors

### Step 2: Add Detailed Logging

Add this to your `/api/daily-summary/generate` endpoint:

```javascript
router.get('/api/daily-summary/generate', authenticate, async (req, res) => {
    console.log('========================================');
    console.log('AI DAILY SUMMARY GENERATION REQUEST');
    console.log('User ID:', req.user?.id);
    console.log('Date:', req.query.date);
    console.log('Timezone:', req.query.timezone);
    console.log('Timestamp:', new Date().toISOString());
    console.log('========================================');

    try {
        // Step 1: Validate inputs
        console.log('Step 1: Validating inputs...');
        const { date, timezone } = req.query;

        if (!date) {
            console.error('❌ Missing date parameter');
            return res.status(400).json({
                path: req.path,
                error: 'Bad Request',
                message: 'Missing required parameter: date',
                timestamp: new Date().toISOString()
            });
        }

        if (!timezone) {
            console.error('❌ Missing timezone parameter');
            return res.status(400).json({
                path: req.path,
                error: 'Bad Request',
                message: 'Missing required parameter: timezone',
                timestamp: new Date().toISOString()
            });
        }

        console.log('✓ Inputs validated');

        // Step 2: Check OpenAI API key
        console.log('Step 2: Checking OpenAI API key...');
        if (!process.env.OPENAI_API_KEY) {
            console.error('❌ OPENAI_API_KEY not set in environment');
            return res.status(500).json({
                path: req.path,
                error: 'Configuration Error',
                message: 'OpenAI API key not configured',
                timestamp: new Date().toISOString()
            });
        }
        console.log('✓ OpenAI API key present');

        // Step 3: Fetch user data
        console.log('Step 3: Fetching user data...');
        const user = await getUserById(req.user.id);
        if (!user) {
            console.error('❌ User not found:', req.user.id);
            return res.status(404).json({
                path: req.path,
                error: 'Not Found',
                message: 'User not found',
                timestamp: new Date().toISOString()
            });
        }
        console.log('✓ User found:', user.email);

        // Step 4: Fetch calendar events
        console.log('Step 4: Fetching calendar events...');
        const events = await getEventsForDate(req.user.id, date, timezone);
        console.log(`✓ Found ${events.length} events`);

        // Step 5: Fetch health metrics
        console.log('Step 5: Fetching health metrics...');
        const healthMetrics = await getHealthMetrics(req.user.id, date);
        console.log('✓ Health metrics fetched:', healthMetrics ? 'yes' : 'no');

        // Step 6: Call OpenAI
        console.log('Step 6: Calling OpenAI API...');
        const startTime = Date.now();

        const summary = await generateAISummary({
            events,
            healthMetrics,
            date,
            timezone
        });

        const duration = ((Date.now() - startTime) / 1000).toFixed(2);
        console.log(`✓ OpenAI completed in ${duration}s`);

        // Step 7: Return response
        console.log('Step 7: Returning response...');
        console.log('Response:', JSON.stringify(summary, null, 2));

        res.json(summary);
        console.log('✓ Response sent successfully');

    } catch (error) {
        console.error('========================================');
        console.error('❌ ERROR IN AI SUMMARY GENERATION');
        console.error('Error type:', error.constructor.name);
        console.error('Error message:', error.message);
        console.error('Error stack:', error.stack);
        console.error('========================================');

        res.status(500).json({
            path: req.path,
            error: 'Internal server error',
            message: error.message, // ⚠️ In production, don't expose internal errors
            details: error.stack, // ⚠️ Remove in production
            timestamp: new Date().toISOString()
        });
    }
});
```

### Step 3: Check Environment Variables

**Verify in Cloud Run:**
```bash
gcloud run services describe alltime-backend \
  --region=us-central1 \
  --format='get(spec.template.spec.containers[0].env)'
```

**Required variables:**
- `OPENAI_API_KEY` - Your OpenAI API key
- `DATABASE_URL` - Connection to PostgreSQL
- `JWT_SECRET` - For authentication

**Set if missing:**
```bash
gcloud run services update alltime-backend \
  --region=us-central1 \
  --set-env-vars OPENAI_API_KEY=sk-proj-...
```

### Step 4: Test OpenAI Connection

Add a test endpoint to verify OpenAI works:

```javascript
router.get('/api/test/openai', authenticate, async (req, res) => {
    try {
        console.log('Testing OpenAI connection...');

        if (!process.env.OPENAI_API_KEY) {
            return res.status(500).json({ error: 'OPENAI_API_KEY not set' });
        }

        const { OpenAI } = require('openai');
        const openai = new OpenAI({
            apiKey: process.env.OPENAI_API_KEY
        });

        const response = await openai.chat.completions.create({
            model: 'gpt-4',
            messages: [
                { role: 'user', content: 'Say "OpenAI is working!"' }
            ],
            max_tokens: 50
        });

        res.json({
            success: true,
            message: response.choices[0].message.content,
            model: response.model
        });

    } catch (error) {
        console.error('OpenAI test error:', error);
        res.status(500).json({
            success: false,
            error: error.message,
            stack: error.stack
        });
    }
});
```

**Test it:**
```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/test/openai"
```

---

## 🔧 Common Fixes

### Fix #1: Set OpenAI API Key

**Problem:** `OPENAI_API_KEY` not set in Cloud Run

**Solution:**
```bash
# Get your OpenAI API key from https://platform.openai.com/api-keys
gcloud run services update alltime-backend \
  --region=us-central1 \
  --set-env-vars OPENAI_API_KEY=sk-proj-YOUR_KEY_HERE

# Verify it's set
gcloud run services describe alltime-backend \
  --region=us-central1 \
  --format='value(spec.template.spec.containers[0].env)'
```

### Fix #2: Install OpenAI Package

**Problem:** OpenAI npm package not installed

**Solution:**
```bash
# In your backend directory
npm install openai

# Verify it's in package.json
cat package.json | grep openai

# Redeploy
npm run build
gcloud run deploy alltime-backend --source .
```

### Fix #3: Fix Database Query

**Problem:** Events or health query crashes

**Solution:**
```javascript
// Make queries safe with try-catch
async function getEventsForDate(userId, date, timezone) {
    try {
        const result = await db.query(`
            SELECT * FROM events
            WHERE user_id = $1
            AND DATE(start_time AT TIME ZONE $3) = $2
            ORDER BY start_time
        `, [userId, date, timezone || 'UTC']);

        return result.rows || [];
    } catch (error) {
        console.error('Error fetching events:', error);
        return []; // Return empty array on error
    }
}
```

### Fix #4: Add Fallback for Missing Data

**Problem:** Crashes when user has no events or health data

**Solution:**
```javascript
const summary = await generateAISummary({
    events: events || [],
    healthMetrics: healthMetrics || null,
    date,
    timezone
});

// In generateAISummary:
if (!events || events.length === 0) {
    return {
        day_summary: ["You have no events scheduled for this day. Perfect time for focused work or rest!"],
        health_summary: ["Health data not available for this date."],
        focus_recommendations: ["Take advantage of your free day to tackle important tasks or recharge."],
        alerts: []
    };
}
```

---

## 🧪 Testing After Fix

### Test 1: Basic Request
```bash
curl -v \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/daily-summary/generate?date=2025-12-06&timezone=America/New_York"
```

**Expected:**
- Status: 200 OK
- Response time: 3-10 seconds
- Valid JSON with 4 fields

### Test 2: Missing Parameters
```bash
# Missing date
curl -H "Authorization: Bearer TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/daily-summary/generate?timezone=America/New_York"

# Expected: 400 Bad Request

# Missing timezone
curl -H "Authorization: Bearer TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/daily-summary/generate?date=2025-12-06"

# Expected: 400 Bad Request
```

### Test 3: Invalid Date
```bash
curl -H "Authorization: Bearer TOKEN" \
  "https://alltime-backend-hicsfvfd7q-uc.a.run.app/api/daily-summary/generate?date=invalid&timezone=America/New_York"

# Expected: 400 Bad Request with clear error message
```

---

## 📋 Checklist for Backend Team

Before deploying:
- [ ] `OPENAI_API_KEY` is set in Cloud Run environment variables
- [ ] `openai` npm package is installed and in `package.json`
- [ ] Database connection works (test with existing endpoints)
- [ ] Added comprehensive logging (Step 1-7 logs above)
- [ ] Added try-catch around all async operations
- [ ] Handle missing data gracefully (empty events, no health data)
- [ ] Return proper error messages (not generic "Internal server error")
- [ ] Test endpoint returns 200 OK with valid data

After deploying:
- [ ] Check Cloud Run logs for startup errors
- [ ] Test `/api/test/openai` endpoint
- [ ] Test `/api/daily-summary/generate` with valid date
- [ ] Verify response time is 3-10 seconds (not 0.07s)
- [ ] Verify response has all 4 required fields
- [ ] Test with user who has no events
- [ ] Test with user who has no health data

---

## 🆘 If Still Failing

### Get Full Stack Trace

1. **Enable detailed logging in Cloud Run:**
```bash
gcloud logging read \
  "resource.type=cloud_run_revision" \
  --limit 200 \
  --format json \
  --freshness 5m \
  | jq -r '.[] | select(.severity == "ERROR") | .textPayload'
```

2. **Look for:**
   - "Cannot read property ... of undefined"
   - "OPENAI_API_KEY is not defined"
   - Database connection errors
   - Authentication errors

3. **Share the logs:**
   - Full error message
   - Stack trace
   - Request details (user ID, date, timezone)

### Emergency Fallback

If you can't fix quickly, implement a simple fallback:

```javascript
router.get('/api/daily-summary/generate', authenticate, async (req, res) => {
    try {
        // Try to generate with OpenAI
        const summary = await generateAISummary(...);
        res.json(summary);
    } catch (error) {
        console.error('OpenAI failed, using fallback:', error);

        // Return basic fallback without OpenAI
        res.json({
            day_summary: ["Unable to generate AI summary at this time. Please try again later."],
            health_summary: [],
            focus_recommendations: ["Check back soon for personalized recommendations."],
            alerts: []
        });
    }
});
```

---

## 📞 Next Steps

1. **Check logs immediately** - Find the actual error
2. **Verify OpenAI API key is set** - Most likely cause
3. **Add detailed logging** - Use the code above
4. **Test OpenAI connection** - Use test endpoint
5. **Deploy and test** - Verify 200 OK response

**The iOS app is ready and waiting!** Once the backend returns a 200 with valid data, the app will display the AI summary beautifully.

---

**Created:** December 7, 2025
**Status:** 🚨 Needs Backend Fix
**Priority:** HIGH - App is ready, backend needs debugging

