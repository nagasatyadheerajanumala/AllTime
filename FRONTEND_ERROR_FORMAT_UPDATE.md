# Frontend Error Format Update - Permanent Token System

## Summary
Successfully updated frontend error handling to support the new backend error response format while maintaining backward compatibility.

---

## ✅ Changes Implemented

### 1. Updated Error Detection

#### `isCalendarTokenExpiryError()` Function
**Location:** `APIService.swift`

**Updates:**
- ✅ Now checks for **NEW FORMAT**: `"error": "token_expired"`
- ✅ Maintains **OLD FORMAT** support: `"error": "Calendar token expired"` and `"status": "error"`
- ✅ Backward compatible - supports both formats

**Code:**
```swift
// NEW FORMAT: Check for "error": "token_expired"
if errorType == "token_expired" {
    if provider == "google" || provider == "microsoft" {
        return true
    }
}

// OLD FORMAT: Backward compatibility
if (provider == "google" || provider == "microsoft") &&
   (errorMsg.contains("calendar token") || 
    errorMsg.contains("reconnect calendar") ||
    actionRequired == "reconnect_calendar" ||
    (status == "error" && errorMsg.contains("token expired"))) {
    return true
}
```

---

### 2. Added Transient Failure Detection

#### New Function: `isTransientFailureError()`
**Location:** `APIService.swift`

**Purpose:** Detects `"error": "transient_failure"` errors (retryable failures)

**Returns:**
- `isTransient: Bool` - Whether this is a transient failure
- `retryable: Bool` - Whether the error is retryable
- `message: String?` - Error message

**Code:**
```swift
private func isTransientFailureError(responseData: Data?) -> (isTransient: Bool, retryable: Bool, message: String?) {
    guard let data = responseData,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return (false, false, nil)
    }
    
    let errorType = (json["error"] as? String ?? "").lowercased()
    
    if errorType == "transient_failure" {
        let retryable = json["retryable"] as? Bool ?? true
        let message = json["message"] as? String
        return (true, retryable, message)
    }
    
    return (false, false, nil)
}
```

---

### 3. Updated `validateResponse()` Function

#### Token Expiry Handling
**Location:** `APIService.swift`

**Updates:**
- ✅ Checks for **NEW FORMAT**: `"error": "token_expired"` with provider
- ✅ Maintains **OLD FORMAT** support for backward compatibility
- ✅ Posts appropriate notifications (`GoogleCalendarTokenExpired` or `MicrosoftCalendarTokenExpired`)

**Code:**
```swift
// NEW FORMAT: Token expired
if errorType == "token_expired" && (provider == "google" || provider == "microsoft") {
    let notificationName = provider == "microsoft" ?
        NSNotification.Name("MicrosoftCalendarTokenExpired") :
        NSNotification.Name("GoogleCalendarTokenExpired")
    
    NotificationCenter.default.post(
        name: notificationName,
        object: nil,
        userInfo: ["error": backendError, "provider": provider]
    )
}
```

#### Transient Failure Handling
**Location:** `APIService.swift`

**Updates:**
- ✅ Detects `"error": "transient_failure"` (HTTP 500)
- ✅ Extracts `retryable` flag from response
- ✅ Throws `NSError` with `error_type: "transient_failure"` in userInfo

**Code:**
```swift
// NEW FORMAT: Transient failure (500 status)
else if errorType == "transient_failure" && httpResponse.statusCode == 500 {
    let retryable = errorJSON["retryable"] as? Bool ?? true
    
    throw NSError(
        domain: "AllTime",
        code: 500,
        userInfo: [
            NSLocalizedDescriptionKey: backendError,
            "error_type": "transient_failure",
            "retryable": retryable,
            "provider": provider,
            "code": "TRANSIENT_FAILURE"
        ]
    )
}
```

---

### 4. Updated `CalendarViewModel` Error Handling

#### Transient Failure Support
**Location:** `CalendarViewModel.swift`

**Updates:**
- ✅ Detects transient failures from error userInfo
- ✅ Shows retry button for retryable failures
- ✅ Does NOT show reconnect prompt for transient failures
- ✅ Maintains existing token expiry handling

**Code:**
```swift
// UPDATED: Check for transient failure (new error format)
if let nsError = error as NSError?,
   let errorType = nsError.userInfo["error_type"] as? String,
   errorType == "transient_failure" {
    let retryable = nsError.userInfo["retryable"] as? Bool ?? true
    
    if retryable {
        syncError = "Calendar sync failed temporarily. Tap to retry."
        // Show retry button (handled by SyncErrorBanner)
    } else {
        syncError = errorDesc
    }
}
```

---

### 5. Updated `APIError` Model

#### Added userInfo Support
**Location:** `AuthResponse.swift`

**Updates:**
- ✅ Added optional `userInfo: [String: Any]?` property
- ✅ Custom initializer supports userInfo
- ✅ userInfo is not encoded/decoded (runtime only)

**Code:**
```swift
struct APIError: Codable, Error {
    let message: String
    let code: String?
    let details: String?
    var userInfo: [String: Any]? = nil
    
    init(message: String, code: String? = nil, details: String? = nil, userInfo: [String: Any]? = nil) {
        self.message = message
        self.code = code
        self.details = details
        self.userInfo = userInfo
    }
}
```

---

## 📋 Error Response Formats Supported

### 1. Token Expired (401) - NEW FORMAT
```json
{
  "error": "token_expired",
  "provider": "google",
  "message": "Google Calendar token expired or revoked. User must reconnect.",
  "action_required": "reconnect_calendar"
}
```

**Frontend Action:** Shows reconnect UI

---

### 2. Token Expired (401) - OLD FORMAT (Backward Compatible)
```json
{
  "status": "error",
  "error": "Calendar token expired",
  "message": "Google Calendar token expired and automatic refresh failed.",
  "provider": "google",
  "action_required": "reconnect_calendar"
}
```

**Frontend Action:** Shows reconnect UI (still supported)

---

### 3. Transient Failure (500) - NEW FORMAT
```json
{
  "error": "transient_failure",
  "provider": "google",
  "retryable": true,
  "message": "Network timeout or temporary API error"
}
```

**Frontend Action:** Shows retry button (does NOT show reconnect prompt)

---

### 4. Transient Failure (500) - Non-Retryable
```json
{
  "error": "transient_failure",
  "provider": "google",
  "retryable": false,
  "message": "Unexpected error occurred"
}
```

**Frontend Action:** Shows error message (no retry button)

---

## 🔄 Backward Compatibility

### ✅ Fully Backward Compatible

**Old Format Still Works:**
- ✅ `"status": "error"` field detection
- ✅ `"error": "Calendar token expired"` message detection
- ✅ All existing error handling paths preserved

**New Format Added:**
- ✅ `"error": "token_expired"` detection
- ✅ `"error": "transient_failure"` detection
- ✅ Graceful fallback to old format if new format not detected

**Migration Strategy:**
```swift
// Supports both old and new formats
let errorType = (json["error"] as? String ?? "").lowercased()

// NEW FORMAT
if errorType == "token_expired" {
    // Handle new format
}
// OLD FORMAT
else if errorMsg.contains("calendar token expired") {
    // Handle old format
}
```

---

## 🎯 User Experience

### Token Expired
- **UI:** Shows reconnect alert
- **Action:** User can reconnect calendar
- **No Retry:** Does not show retry button

### Transient Failure (Retryable)
- **UI:** Shows error banner with retry button
- **Action:** User can retry sync
- **No Reconnect:** Does NOT show reconnect prompt

### Transient Failure (Non-Retryable)
- **UI:** Shows error message
- **Action:** User sees error, no retry option

---

## 📁 Files Modified

1. **`AllTime/Services/APIService.swift`**
   - Updated `isCalendarTokenExpiryError()` to support new format
   - Added `isTransientFailureError()` function
   - Updated `validateResponse()` to handle new error formats
   - Added `extractCalendarTokenExpiryDetails()` helper

2. **`AllTime/Models/AuthResponse.swift`**
   - Updated `APIError` to support `userInfo` property

3. **`AllTime/ViewModels/CalendarViewModel.swift`**
   - Added transient failure detection
   - Updated error handling to show retry for transient failures
   - Maintained token expiry handling

---

## ✅ Testing Checklist

- [x] Token expiry detection (new format)
- [x] Token expiry detection (old format - backward compatible)
- [x] Transient failure detection (retryable)
- [x] Transient failure detection (non-retryable)
- [x] Error messages display correctly
- [x] Reconnect UI shows for token expiry
- [x] Retry button shows for transient failures
- [x] No reconnect prompt for transient failures
- [x] Build successful

---

## 🚀 Ready for Production

All changes are:
- ✅ Fully implemented
- ✅ Backward compatible
- ✅ Error handled
- ✅ UI components updated
- ✅ Build successful
- ✅ No breaking changes

---

## 📚 Error Handling Flow

### Token Expired Flow
1. Backend returns `"error": "token_expired"` (401)
2. `validateResponse()` detects token expiry
3. Posts `GoogleCalendarTokenExpired` or `MicrosoftCalendarTokenExpired` notification
4. `CalendarViewModel` receives notification
5. Shows reconnect alert
6. User can reconnect calendar

### Transient Failure Flow
1. Backend returns `"error": "transient_failure"` (500)
2. `validateResponse()` detects transient failure
3. Throws `NSError` with `error_type: "transient_failure"` in userInfo
4. `CalendarViewModel` catches error
5. Checks for `error_type == "transient_failure"`
6. Shows error banner with retry button (if retryable)
7. User can retry sync

---

## ✅ All Requirements Met

- ✅ Updated error parsing to check `"error": "token_expired"`
- ✅ Removed dependency on `"status": "error"` field (still supports it for backward compatibility)
- ✅ Added handling for `"error": "transient_failure"` with retry logic
- ✅ Updated UI to show retry button for transient failures
- ✅ Ensured reconnect flow only triggers for `"token_expired"`
- ✅ Maintained backward compatibility with old format
- ✅ Build successful

