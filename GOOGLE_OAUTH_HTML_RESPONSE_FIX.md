# Google OAuth HTML Response Fix

## Issue Description

When attempting to add Google Calendar, the app was failing with a JSON decoding error:

```
❌ GoogleAuthManager: Failed to get OAuth URL: dataCorrupted(Swift.DecodingError.Context(codingPath: [], debugDescription: "The given data was not valid JSON.", underlyingError: Optional(Error Domain=NSCocoaErrorDomain Code=3840 "Unexpected character '<' around line 1, column 1."...
```

The error message indicates the response starts with `<`, which means the backend is returning **HTML instead of JSON**.

## Root Cause

Based on the response headers showing Google Accounts domains, the **most likely issue** is:

### Backend is Performing HTTP Redirect Instead of Returning JSON

The backend `/connections/google/start` endpoint is likely doing an **HTTP redirect** (302/307) to Google's OAuth page instead of returning a JSON response with the authorization URL.

**Wrong (current backend behavior):**
```java
@GetMapping("/connections/google/start")
public void startGoogleOAuth(HttpServletResponse response) {
    String authUrl = buildGoogleOAuthUrl();
    response.sendRedirect(authUrl); // ❌ This redirects the iOS app to Google
}
```

**Correct (expected backend behavior):**
```java
@GetMapping("/connections/google/start")
public ResponseEntity<Map<String, String>> startGoogleOAuth() {
    String authUrl = buildGoogleOAuthUrl();
    return ResponseEntity.ok(Map.of("authorization_url", authUrl)); // ✅ Returns JSON
}
```

### Why This Happens

- **URLSession follows redirects automatically** - When the backend returns a 302 redirect to Google, URLSession follows it
- **Google returns HTML** - The iOS app ends up with Google's login page HTML instead of your backend's JSON
- **JSON decoder fails** - Trying to decode HTML as JSON causes the error you're seeing

### Other Possible Causes

1. **Backend endpoint doesn't exist** - Returns a 404 error page (HTML)
2. **Unhandled exception** - Returns Spring Boot's default error page (HTML)
3. **Authentication failure** - Returns an HTML error page instead of JSON error

## Current Configuration

- **Base URL**: `https://alltime-backend-756952284083.us-central1.run.app`
- **Endpoint**: `/connections/google/start`
- **Expected Response**: JSON with `{ "authorization_url": "..." }`
- **Actual Response**: HTML error page

## Frontend Fix Applied

### 1. Enhanced Error Detection in `APIService.swift`

Updated both `getGoogleOAuthStartURL()` and `getMicrosoftOAuthStartURL()` methods to:

- **Detect HTTP redirects** - Check if the response URL changed to Google/Microsoft domains
- Log the response URL to identify redirects
- Log the first 500 characters of the response for debugging
- Detect if the response is HTML (starts with `<`)
- Throw clear error messages for each scenario
- Provide detailed error logging with the full response

**Redirect Detection:**
```swift
let responseURL = (response as? HTTPURLResponse)?.url?.absoluteString ?? "unknown"

if responseURL.contains("accounts.google.com") {
    throw APIError(
        message: "Backend misconfiguration: The backend is redirecting to Google instead of returning a JSON response..."
    )
}
```

**HTML Detection:**
```swift
if responseString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") {
    throw APIError(
        message: "Backend returned invalid response (HTML instead of JSON)..."
    )
}
```

### 2. User-Friendly Error Messages in `GoogleAuthManager.swift`

Enhanced error handling to show specific, helpful messages based on the type of error:

```swift
if let apiError = error as? APIError {
    if apiError.message.contains("redirected to Google") || apiError.message.contains("Backend misconfiguration") {
        self.errorMessage = "Backend configuration error: The server is performing a redirect instead of returning the authorization URL."
    } else if apiError.message.contains("HTML instead of JSON") {
        self.errorMessage = "Backend error: Server returned an error page."
    } else {
        self.errorMessage = "Failed to start authentication: \(apiError.message)"
    }
}
```

## What to Check on Backend

### **CRITICAL: Fix the Redirect Issue**

If your backend is currently doing this:

```java
@GetMapping("/connections/google/start")
public void startGoogleOAuth(HttpServletResponse response) throws IOException {
    String authUrl = googleOAuthService.buildAuthorizationUrl(userId);
    response.sendRedirect(authUrl); // ❌ WRONG - Don't redirect!
}
```

**Change it to return JSON instead:**

```java
@GetMapping("/connections/google/start")
public ResponseEntity<Map<String, String>> startGoogleOAuth(
    @RequestHeader("Authorization") String authHeader
) {
    try {
        // Extract user from JWT
        String userId = jwtService.getUserIdFromToken(authHeader.substring(7));
        
        // Build OAuth URL with state parameter
        String authorizationUrl = googleOAuthService.buildAuthorizationUrl(userId);
        
        // Return JSON response (NOT a redirect!)
        Map<String, String> response = new HashMap<>();
        response.put("authorization_url", authorizationUrl);
        
        return ResponseEntity.ok(response); // ✅ CORRECT - Return JSON
    } catch (Exception e) {
        log.error("Failed to generate Google OAuth URL", e);
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of("error", "internal_error", "message", e.getMessage()));
    }
}
```

### Key Points for Backend Implementation

1. **DO NOT use `response.sendRedirect()`** - This causes the iOS app to follow the redirect and receive HTML
2. **DO return JSON** - Return `{"authorization_url": "https://accounts.google.com/..."}`
3. **Handle errors as JSON** - Never return HTML error pages
4. **Use snake_case for JSON keys** - Follow the API convention: `authorization_url` not `authorizationUrl`

### 1. Verify Endpoint Exists

Check that the Spring Boot backend has this endpoint properly configured:

```java
@GetMapping("/connections/google/start")
public ResponseEntity<Map<String, String>> startGoogleOAuth(
    @RequestHeader("Authorization") String authHeader
) {
    // Should return JSON: { "authorization_url": "https://..." }
}
```

### 2. Check Backend Logs

Run the backend and look for errors when calling `/connections/google/start`:

```bash
# Check Cloud Run logs
gcloud logging read "resource.type=cloud_run_revision" --limit 50 --format json
```

### 3. Test Endpoint Directly

Test the endpoint using curl:

```bash
# Replace YOUR_JWT_TOKEN with an actual token from the app
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/connections/google/start" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -v
```

Expected response:
```json
{
  "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?..."
}
```

### 4. Common Backend Issues to Check

- **Exception Handling**: Ensure all exceptions return JSON, not HTML
- **Security Configuration**: Check if Spring Security is blocking the request
- **CORS Configuration**: Verify CORS is properly configured
- **Controller Mapping**: Ensure the route is correctly mapped
- **JWT Validation**: Check if the JWT token is being validated correctly

### 5. Backend Error Response Format

The backend should always return JSON errors, even for failures:

```java
@ExceptionHandler(Exception.class)
public ResponseEntity<Map<String, String>> handleException(Exception e) {
    return ResponseEntity
        .status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(Map.of("error", "internal_error", "message", e.getMessage()));
}
```

## Testing the Fix

### 1. Run the App

The app will now show specific error messages:

**If backend is redirecting:**
```
Backend configuration error: The server is performing a redirect instead of returning the authorization URL. Please check the backend /connections/google/start endpoint.
```

**If backend returns HTML error page:**
```
Backend error: Server returned an error page. Please check that the backend is running correctly.
```

### 2. Check Console Logs

**For redirect detection:**
```
🔗 APIService: Response status: 200
🔗 APIService: Response URL: https://accounts.google.com/o/oauth2/v2/auth?...
❌ APIService: Backend redirected to Google instead of returning JSON
❌ APIService: This means the backend is configured for browser-based OAuth, not mobile app OAuth
```

**For HTML response:**
```
🔗 APIService: Response data (first 500 chars): <!DOCTYPE html>...
❌ APIService: Backend returned HTML instead of JSON - likely an error page or redirect
❌ APIService: Full response: [full HTML content]
```

### 3. Fix Backend, Then Test

Once the backend is fixed to return proper JSON, the OAuth flow should work:

1. User taps "Connect Google Calendar"
2. App calls `/connections/google/start`
3. Backend returns JSON with authorization URL
4. App opens OAuth URL in web view
5. User authorizes
6. Callback completes the connection

## Files Modified

1. **AllTime/Services/APIService.swift**
   - Enhanced `getGoogleOAuthStartURL()` with HTML detection
   - Enhanced `getMicrosoftOAuthStartURL()` with HTML detection
   - Added detailed response logging

2. **AllTime/Services/GoogleAuthManager.swift**
   - Improved error messages for HTML responses
   - Better user feedback

## Next Steps

1. **Check Backend**: Verify the `/connections/google/start` endpoint is working
2. **Test with curl**: Manually test the endpoint to see what it returns
3. **Fix Backend**: Ensure the endpoint returns proper JSON
4. **Retest**: Try connecting Google Calendar again in the app

## Expected Behavior After Backend Fix

1. User taps "Connect Google Calendar"
2. App shows loading indicator
3. Backend returns JSON with Google OAuth URL
4. Web view opens with Google sign-in
5. User authorizes AllTime
6. Success callback received
7. Google Calendar is connected
8. Events sync automatically

---

**Status**: Frontend fixes applied ✅  
**Requires**: Backend endpoint fix ⚠️  
**Priority**: High - blocks Google Calendar integration

