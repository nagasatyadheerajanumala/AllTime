# Apple Developer Portal Setup for EventKit

## ✅ Required Steps in Apple Developer Portal

### 1. Enable EventKit Capability in App ID

**Location:** [developer.apple.com](https://developer.apple.com) → Certificates, Identifiers & Profiles → Identifiers

**Steps:**
1. Find your App ID: `com.storillc.AllTime`
2. Click on it to edit
3. Scroll to **Capabilities** section
4. Check the box for **EventKit** (or **Reminders**)
5. Click **Save**

**Note:** If you don't see EventKit as an option, it may be automatically enabled when the entitlement is present. However, it's good practice to verify it's enabled.

### 2. Regenerate Provisioning Profiles

After enabling EventKit in the App ID:

1. Go to **Profiles** section
2. Find your provisioning profiles for `com.storillc.AllTime`
3. For each profile (Development, Distribution):
   - Click **Edit**
   - Click **Generate** (this regenerates with updated capabilities)
   - Download the new profile
   - Install in Xcode (or let Xcode auto-download)

**Alternative:** If using Automatic Signing in Xcode:
- Xcode will automatically regenerate profiles when you build
- Just ensure your Apple Developer account is connected in Xcode

### 3. Add Privacy Description to Info.plist

**File:** `AllTime/Info.plist` (or add to project settings)

Add this key:

```xml
<key>NSRemindersUsageDescription</key>
<string>AllTime needs access to your reminders to sync reminders created in the app to your iOS Reminders app.</string>
```

**Or in Xcode:**
1. Select project → Target "AllTime" → Info tab
2. Add new row
3. Key: `Privacy - Reminders Usage Description`
4. Value: `AllTime needs access to your reminders to sync reminders created in the app to your iOS Reminders app.`

## 📋 Current Configuration

### Bundle Identifier
- **ID:** `com.storillc.AllTime`

### Capabilities Already Configured
- ✅ Sign in with Apple
- ✅ HealthKit
- ✅ Push Notifications
- ✅ **EventKit** (added in entitlements)

### Entitlements File
- **File:** `AllTime/AllTime.entitlements`
- **EventKit Key:** `com.apple.developer.eventkit` = `true`

## 🔍 Verification Checklist

After making changes in Apple Developer Portal:

- [ ] EventKit capability enabled in App ID
- [ ] Provisioning profiles regenerated
- [ ] `NSRemindersUsageDescription` added to Info.plist
- [ ] Xcode project builds successfully
- [ ] App requests Reminders permission when creating reminder with sync enabled

## 🚨 Important Notes

1. **Automatic Signing:**
   - If using Automatic Signing, Xcode will handle profile regeneration
   - Just ensure your team is selected in Signing & Capabilities

2. **Manual Signing:**
   - You must manually download and install updated provisioning profiles
   - Profiles must include EventKit capability

3. **Testing:**
   - After enabling EventKit, test on a physical device
   - Simulator may not fully support EventKit reminders
   - First launch will prompt for Reminders permission

4. **Capability vs Entitlement:**
   - **Capability** = Enabled in Apple Developer Portal (App ID)
   - **Entitlement** = Declared in entitlements file (already done)
   - Both are required for EventKit to work

## 📝 Summary

**What you need to do:**
1. ✅ Enable EventKit in App ID (if not auto-enabled)
2. ✅ Regenerate provisioning profiles
3. ✅ Add `NSRemindersUsageDescription` to Info.plist

**What's already done:**
- ✅ EventKit entitlement added to `AllTime.entitlements`
- ✅ EventKit integration code implemented
- ✅ UI for sync toggle added

---

**Status:** Entitlement is configured. Just need to enable in Apple Developer Portal and add privacy description.

