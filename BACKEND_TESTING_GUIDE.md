# Backend Testing Guide - Google OAuth Fix

## Issue Summary

The iOS app is receiving HTML instead of JSON from the `/connections/google/start` endpoint. Based on your API documentation, the endpoint should return:

```json
{
  "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?..."
}
```

But instead, it's either:
1. **Performing an HTTP 302/307 redirect** to Google (most likely)
2. **Returning an HTML error page**

## How to Test Your Backend

### Step 1: Get a Valid Access Token

First, sign in with Apple to get a JWT token:

```bash
# You'll need to get this from the iOS app after signing in
# Check Keychain or print it in the app
ACCESS_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

### Step 2: Test the Google OAuth Start Endpoint

```bash
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/connections/google/start" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Accept: application/json" \
  -v
```

### Expected Response (✅ CORRECT)

**Status**: `200 OK`
**Content-Type**: `application/json`
**Body**:
```json
{
  "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?client_id=756952284083-45ajqmld27ouvj0437me9tjftjitlnbq.apps.googleusercontent.com&redirect_uri=https://alltime-backend-756952284083.us-central1.run.app/connections/google/callback&response_type=code&scope=https://www.googleapis.com/auth/calendar%20https://www.googleapis.com/auth/userinfo.email&access_type=offline&prompt=consent&state=user_1_1733332800000"
}
```

### Common Wrong Responses

#### ❌ Wrong Response 1: HTTP Redirect (Most Likely Issue)

```bash
< HTTP/1.1 302 Found
< Location: https://accounts.google.com/o/oauth2/v2/auth?...
< Content-Length: 0
```

**Problem**: Backend is doing `response.sendRedirect()` instead of returning JSON.

**Fix**: Change your backend controller:

```java
// ❌ WRONG - Don't do this
@GetMapping("/connections/google/start")
public void startGoogleOAuth(HttpServletResponse response) throws IOException {
    String authUrl = buildAuthorizationUrl();
    response.sendRedirect(authUrl); // This causes the iOS app to receive HTML
}

// ✅ CORRECT - Do this instead
@GetMapping("/connections/google/start")
public ResponseEntity<Map<String, String>> startGoogleOAuth(
    @RequestHeader("Authorization") String authHeader
) {
    try {
        String userId = jwtService.getUserIdFromToken(authHeader.substring(7));
        String authUrl = googleOAuthService.buildAuthorizationUrl(userId);
        
        return ResponseEntity.ok(Map.of("authorization_url", authUrl));
    } catch (Exception e) {
        log.error("Failed to generate Google OAuth URL", e);
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of("error", "internal_error", "message", e.getMessage()));
    }
}
```

#### ❌ Wrong Response 2: HTML Error Page

```html
<!DOCTYPE html>
<html>
<head><title>Error</title></head>
<body>
<h1>Internal Server Error</h1>
...
</body>
</html>
```

**Problem**: Unhandled exception or missing endpoint returning default error page.

**Fix**: 
1. Verify the endpoint exists in your controller
2. Add proper exception handling
3. Configure Spring to return JSON errors

```java
@ControllerAdvice
public class GlobalExceptionHandler {
    
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleException(Exception e) {
        log.error("Unhandled exception", e);
        return ResponseEntity
            .status(HttpStatus.INTERNAL_SERVER_ERROR)
            .body(Map.of(
                "error", "internal_error",
                "message", e.getMessage()
            ));
    }
}
```

#### ❌ Wrong Response 3: 401 Unauthorized

```json
{
  "error": "Unauthorized",
  "message": "Invalid or expired JWT token"
}
```

**Problem**: JWT validation is failing.

**Fix**: 
1. Verify the JWT token is valid
2. Check JWT secret configuration
3. Verify token hasn't expired

## Backend Checklist

Use this checklist to verify your backend implementation:

### ✅ Controller Implementation

- [ ] Endpoint exists: `GET /connections/google/start`
- [ ] Accepts JWT in `Authorization: Bearer {token}` header
- [ ] Returns JSON, NOT redirect
- [ ] Returns `{"authorization_url": "..."}`
- [ ] Uses snake_case for JSON keys (`authorization_url`, not `authorizationUrl`)
- [ ] Includes proper CORS headers
- [ ] Has exception handling that returns JSON

### ✅ OAuth URL Generation

- [ ] Includes `client_id` from Google Console
- [ ] Includes `redirect_uri` pointing to your backend callback
- [ ] Includes `response_type=code`
- [ ] Includes `scope` for calendar and email
- [ ] Includes `access_type=offline` (for refresh tokens)
- [ ] Includes `prompt=consent` (to ensure refresh token)
- [ ] Includes `state` parameter with user ID

### ✅ Security Configuration

- [ ] Endpoint is accessible with valid JWT
- [ ] CORS allows requests from iOS app
- [ ] JWT validation is working
- [ ] Google OAuth credentials are configured

### ✅ Error Handling

- [ ] All errors return JSON, not HTML
- [ ] 401 errors for invalid JWT
- [ ] 500 errors for server issues
- [ ] Clear error messages

## Testing from iOS App

After fixing the backend, test from the iOS app:

### 1. Enable Detailed Logging

The iOS app now has enhanced logging. After tapping "Connect Google Calendar", check the Xcode console:

#### If Backend is Still Redirecting:

```
🔗 APIService: Response status: 200
🔗 APIService: Response URL: https://accounts.google.com/o/oauth2/v2/auth?...
❌ APIService: Backend redirected to Google instead of returning JSON
❌ APIService: This means the backend is configured for browser-based OAuth, not mobile app OAuth
```

**Error shown to user:**
> Backend configuration error: The server is performing a redirect instead of returning the authorization URL.

#### If Backend Returns HTML:

```
🔗 APIService: Response status: 200
🔗 APIService: Response data (first 500 chars): <!DOCTYPE html>...
❌ APIService: Backend returned HTML instead of JSON - likely an error page or redirect
```

**Error shown to user:**
> Backend error: Server returned an error page.

#### If Backend is Fixed (✅):

```
🔗 APIService: Requesting Google OAuth URL from: https://...
🔗 APIService: Response status: 200
🔗 APIService: Response URL: https://alltime-backend-...
🔗 APIService: Response data (first 500 chars): {"authorization_url":"https://accounts.google.com/..."}
✅ APIService: OAuth URL received: https://accounts.google.com/o/oauth2/v2/auth?...
🔗 GoogleAuthManager: ===== OAUTH URL FROM BACKEND =====
🔗 GoogleAuthManager: OAuth URL: https://accounts.google.com/...
🔗 GoogleAuthManager: Opening OAuth URL with callback scheme: alltime
```

Then the OAuth web view will open correctly!

## Complete Test Flow

### 1. Test Sign In (Verify JWT)

```bash
# This should work if your Apple Sign-In is configured
curl -X POST \
  "https://alltime-backend-756952284083.us-central1.run.app/auth/apple" \
  -H "Content-Type: application/json" \
  -d '{
    "identityToken": "YOUR_APPLE_IDENTITY_TOKEN",
    "email": "test@example.com"
  }'
```

Expected: JWT tokens returned

### 2. Test Google OAuth Start (THIS IS THE FAILING ENDPOINT)

```bash
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/connections/google/start" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -v
```

Expected: JSON with `authorization_url`

### 3. Test Connection Status

```bash
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/connections/google/status" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected: `{"connected": false, ...}` (before connecting)

### 4. Test Sync Status

```bash
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/sync/status" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

Expected: Sync status with no Google events

## Quick Fix Code

If your backend controller looks like this:

```java
@RestController
@RequestMapping("/connections")
public class ConnectionController {
    
    @GetMapping("/google/start")
    public void startGoogleOAuth(HttpServletResponse response) throws IOException {
        // ❌ This is causing the issue
        String authUrl = googleOAuthService.buildAuthorizationUrl();
        response.sendRedirect(authUrl);
    }
}
```

Change it to:

```java
@RestController
@RequestMapping("/connections")
public class ConnectionController {
    
    @Autowired
    private GoogleOAuthService googleOAuthService;
    
    @Autowired
    private JwtService jwtService;
    
    @GetMapping("/google/start")
    public ResponseEntity<Map<String, String>> startGoogleOAuth(
        @RequestHeader("Authorization") String authHeader
    ) {
        try {
            // Extract user ID from JWT
            String token = authHeader.substring(7); // Remove "Bearer "
            String userId = jwtService.getUserIdFromToken(token);
            
            // Build OAuth URL with state parameter
            String authorizationUrl = googleOAuthService.buildAuthorizationUrl(userId);
            
            // ✅ Return JSON instead of redirect
            Map<String, String> response = new HashMap<>();
            response.put("authorization_url", authorizationUrl);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            log.error("Failed to generate Google OAuth URL", e);
            
            Map<String, String> error = new HashMap<>();
            error.put("error", "internal_error");
            error.put("message", e.getMessage());
            
            return ResponseEntity
                .status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(error);
        }
    }
}
```

## Verifying the Fix Works

Once you've updated the backend:

### 1. Test with curl (Should see JSON)

```bash
curl -X GET \
  "https://alltime-backend-756952284083.us-central1.run.app/connections/google/start" \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Accept: application/json"
```

Should return:
```json
{
  "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth?client_id=..."
}
```

### 2. Test in iOS App

1. Open AllTime app
2. Sign in with Apple
3. Go to Settings → Connected Calendars
4. Tap "Connect Google Calendar"
5. Should see Google OAuth web view open
6. Sign in and authorize
7. Should see success message

### 3. Verify Events Sync

1. After connecting Google Calendar
2. Go to Calendar tab
3. Should see events from Google Calendar
4. Check console logs for sync success

## Summary

**Root Cause**: Backend is performing HTTP redirect instead of returning JSON

**iOS Fix**: ✅ Already applied - app now detects and reports this clearly

**Backend Fix**: Change endpoint to return JSON instead of using `response.sendRedirect()`

**Testing**: Use curl to verify JSON response before testing in iOS app

---

**Next Steps**:
1. Update backend controller as shown above
2. Deploy backend changes
3. Test with curl to verify JSON response
4. Test in iOS app - should now work!

