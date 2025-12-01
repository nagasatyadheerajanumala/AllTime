# Backend Fix Required: Health Insights API Date Range Filtering

## 🚨 Critical Issue

The `/api/v1/health/insights` endpoint is **not respecting the `start_date` and `end_date` query parameters**. The backend returns the same data regardless of the requested date range, causing the frontend to display identical summaries and charts for "Last 7 Days", "Last 14 Days", and "Last 30 Days".

## 📋 Current API Contract

**Endpoint:** `GET /api/v1/health/insights`

**Query Parameters:**
- `start_date` (optional): Date string in format `yyyy-MM-dd` (e.g., `2025-11-18`)
- `end_date` (optional): Date string in format `yyyy-MM-dd` (e.g., `2025-11-25`)

**Expected Behavior:**
- When `start_date` and `end_date` are provided, return health insights **only for that date range**
- When parameters are omitted, return a default range (e.g., last 7 days)

**Current Behavior:**
- ❌ Always returns the same data regardless of query parameters
- ❌ `per_day_metrics` array contains the same entries for all date ranges
- ❌ `summary_stats`, `ai_narrative`, `trend_analysis`, and `health_breakdown` are calculated from the same fixed date range

## 🔍 Frontend Request Examples

### Example 1: Last 7 Days
```
GET /api/v1/health/insights?start_date=2025-11-18&end_date=2025-11-25
```
**Expected:** 7 days of data (Nov 18 - Nov 25, inclusive)

### Example 2: Last 14 Days
```
GET /api/v1/health/insights?start_date=2025-11-11&end_date=2025-11-25
```
**Expected:** 14 days of data (Nov 11 - Nov 25, inclusive)

### Example 3: Last 30 Days
```
GET /api/v1/health/insights?start_date=2025-10-26&end_date=2025-11-25
```
**Expected:** 30 days of data (Oct 26 - Nov 25, inclusive)

## ✅ Required Backend Changes

### 1. Filter `per_day_metrics` by Date Range

The `per_day_metrics` array must only include entries where `date` falls within `[start_date, end_date]` (inclusive).

**Current Issue:**
```json
{
  "per_day_metrics": [
    {"date": "2025-11-19", ...},
    {"date": "2025-11-20", ...},
    {"date": "2025-11-21", ...},
    // ... same 7 entries regardless of start_date/end_date
  ]
}
```

**Expected:**
- For 7-day range: 7 entries
- For 14-day range: 14 entries
- For 30-day range: 30 entries (or all available if less than 30)

### 2. Recalculate Aggregated Fields Based on Date Range

All aggregated fields must be recalculated based on the **filtered** `per_day_metrics`:

- **`summary_stats`**: Calculate averages, totals, and trends from the filtered date range
- **`ai_narrative`**: Generate narrative based on the filtered date range
- **`trend_analysis`**: Analyze trends within the filtered date range
- **`health_breakdown`**: Breakdown metrics from the filtered date range
- **`insights`**: Generate insights based on the filtered date range

**Current Issue:**
- All aggregated fields are calculated from a fixed 7-day window
- Changing `start_date`/`end_date` doesn't affect these calculations

### 3. Update Response Metadata

The response should include accurate date range information:

```json
{
  "start_date": "2025-11-18",  // Should match query parameter
  "end_date": "2025-11-25",    // Should match query parameter
  "days": 7,                    // Should be (end_date - start_date) + 1
  "per_day_metrics": [...],     // Filtered to date range
  "summary_stats": {...},        // Calculated from filtered data
  "ai_narrative": {...},         // Generated from filtered data
  ...
}
```

## 🗄️ Database Query Requirements

### SQL Query Pattern

When querying `daily_health_metrics` table, filter by date range:

```sql
SELECT *
FROM daily_health_metrics
WHERE user_id = ?
  AND date >= ?  -- start_date
  AND date <= ?  -- end_date
ORDER BY date ASC;
```

### Date Handling

- **Timezone:** Use UTC for database storage and queries
- **Inclusive Range:** Both `start_date` and `end_date` should be inclusive
- **Date Format:** Parse `yyyy-MM-dd` format from query parameters
- **Validation:** Validate that `start_date <= end_date`

## 📊 Response Structure

The response structure should remain the same, but all fields must reflect the filtered date range:

```typescript
interface HealthInsightsResponse {
  start_date: string;           // From query parameter
  end_date: string;             // From query parameter
  days: number;                 // Calculated: (end_date - start_date) + 1
  per_day_metrics: PerDayMetrics[];  // Filtered to date range
  summary_stats: SummaryStats;        // Calculated from filtered data
  ai_narrative: AINarrative;          // Generated from filtered data
  insights: Insight[];                  // Based on filtered data
  trend_analysis?: TrendAnalysis[];    // Trends within date range
  health_breakdown?: HealthBreakdown;  // Breakdown of filtered data
}
```

## 🧪 Test Cases

### Test 1: 7-Day Range
```
Request: GET /api/v1/health/insights?start_date=2025-11-18&end_date=2025-11-25
Expected:
- per_day_metrics.length === 7
- All dates in range [2025-11-18, 2025-11-25]
- summary_stats reflects 7 days of data
```

### Test 2: 14-Day Range
```
Request: GET /api/v1/health/insights?start_date=2025-11-11&end_date=2025-11-25
Expected:
- per_day_metrics.length === 14
- All dates in range [2025-11-11, 2025-11-25]
- summary_stats reflects 14 days of data (different from 7-day)
```

### Test 3: 30-Day Range
```
Request: GET /api/v1/health/insights?start_date=2025-10-26&end_date=2025-11-25
Expected:
- per_day_metrics.length === 30 (or available days if less)
- All dates in range [2025-10-26, 2025-11-25]
- summary_stats reflects 30 days of data (different from 7-day and 14-day)
```

### Test 4: No Parameters (Default)
```
Request: GET /api/v1/health/insights
Expected:
- Default to last 7 days (or reasonable default)
- Return data for default range
```

## 🔧 Implementation Checklist

- [ ] Parse `start_date` and `end_date` query parameters
- [ ] Validate date format (`yyyy-MM-dd`)
- [ ] Validate `start_date <= end_date`
- [ ] Filter `daily_health_metrics` table by date range in SQL query
- [ ] Filter `per_day_metrics` array to only include dates in range
- [ ] Recalculate `summary_stats` from filtered `per_day_metrics`
- [ ] Regenerate `ai_narrative` based on filtered date range
- [ ] Recalculate `trend_analysis` from filtered data
- [ ] Recalculate `health_breakdown` from filtered data
- [ ] Generate `insights` based on filtered date range
- [ ] Update response `start_date`, `end_date`, and `days` fields
- [ ] Add unit tests for different date ranges
- [ ] Add integration tests verifying different ranges return different data

## 📝 Notes

1. **Performance:** Consider indexing the `date` column in `daily_health_metrics` table for efficient range queries
2. **Caching:** If using caching, ensure cache keys include the date range to avoid serving wrong data
3. **AI Narrative:** The AI narrative generation should be aware of the date range context (e.g., "Over the past 7 days" vs "Over the past 30 days")
4. **Empty Ranges:** Handle cases where no data exists for the requested range gracefully (return empty arrays, not errors)

## 🚀 Priority

**HIGH** - This is blocking the frontend from displaying accurate health insights for different time periods. Users cannot see meaningful differences between 7-day, 14-day, and 30-day views.

---

## ✅ Backend Fix Status

**Status:** ✅ **FIXED AND DEPLOYED** - Backend team has completed and deployed the fix.

### Changes Made by Backend:
- ✅ Fixed parameter name mismatch (`start_date` and `end_date` with underscores)
- ✅ Added date validation (`start_date <= end_date`)
- ✅ Added `days` field to response
- ✅ Enhanced logging for debugging
- ✅ Verified repository query and service logic are correct
- ✅ **DEPLOYED** - Backend fix is now live and working

### Frontend Status:
- ✅ Frontend already sends correct parameter names (`start_date`, `end_date`)
- ✅ Frontend enhanced with comprehensive verification logging
- ✅ Frontend cache is keyed by date range (separate cache for 7/14/30 day ranges)
- ✅ Frontend ready and compatible with fixed backend
- ✅ Date range filtering now working correctly
- ✅ Instant loading from cache for each date range
- ✅ Background refresh with proper date range filtering

### Verification Logging:
The frontend includes comprehensive logging to verify the backend fix:
- ✅ Logs requested date range
- ✅ Logs response date range
- ✅ Verifies date range matches request
- ✅ Logs `days` field from backend
- ✅ Logs `per_day_metrics` count
- ✅ Verifies `days` matches `per_day_metrics.count`
- ✅ Logs first and last dates in response
- ✅ Warns if date ranges don't match

### Expected Behavior Now:
1. **7-Day Range**: Returns exactly 7 days of data
2. **14-Day Range**: Returns exactly 14 days of data (different from 7-day)
3. **30-Day Range**: Returns exactly 30 days of data (different from 7-day and 14-day)
4. **Aggregated Stats**: Recalculated based on the filtered date range
5. **AI Narrative**: Generated based on the filtered date range
6. **Trends & Insights**: Based on the filtered date range

**Integration Status:** ✅ **COMPLETE** - Frontend and backend are fully integrated and working correctly. Date range filtering is now functional.

