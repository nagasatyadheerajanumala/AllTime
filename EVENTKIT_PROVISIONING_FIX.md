# Fix EventKit Provisioning Profile Issue

## 🚨 Problem
Xcode shows: **"Provisioning profile 'AllTime' doesn't include the com.apple.developer.eventkit entitlement"**

EventKit doesn't appear as a capability in Xcode's UI because it's not a standard capability - it's an entitlement that must be enabled in the Apple Developer portal.

## ✅ Solution Steps

### Option 1: Enable in Apple Developer Portal (Recommended)

1. **Go to Apple Developer Portal:**
   - Visit: [developer.apple.com](https://developer.apple.com)
   - Sign in with your Apple Developer account

2. **Navigate to Identifiers:**
   - Click **Certificates, Identifiers & Profiles**
   - Click **Identifiers** in the left sidebar
   - Find and click on **`com.storillc.AllTime`**

3. **Enable EventKit:**
   - Scroll down to **Capabilities** section
   - Look for **EventKit** or **Reminders** checkbox
   - ✅ **Check the box** to enable it
   - Click **Save** (top right)

4. **Regenerate Provisioning Profile:**
   - Go to **Profiles** section
   - Find your **"AllTime"** provisioning profile
   - Click **Edit**
   - Click **Generate** (this creates a new profile with EventKit)
   - **Download** the new profile
   - **Double-click** to install in Xcode (or drag to Xcode icon)

5. **In Xcode:**
   - Go to **Signing & Capabilities** tab
   - The error should disappear after the new profile is installed
   - If it doesn't, try **Product → Clean Build Folder** (Shift+Cmd+K)
   - Then rebuild

### Option 2: Switch to Automatic Signing (Easier)

If you prefer automatic management:

1. **In Xcode:**
   - Go to **Signing & Capabilities** tab
   - ✅ **Check "Automatically manage signing"**
   - Select your **Team**: "STORI LLC"
   - Xcode will automatically:
     - Enable EventKit in App ID
     - Generate new provisioning profile with EventKit
     - Install the profile

2. **Verify:**
   - The red error should disappear
   - Build the project to confirm

### Option 3: Manual Profile Update (If EventKit option not visible)

If you don't see EventKit in the portal:

1. **The entitlement is already in your entitlements file** ✅
2. **You just need to regenerate the profile:**
   - Go to **Profiles** in Apple Developer portal
   - Edit your "AllTime" profile
   - Click **Generate** (even without seeing EventKit option)
   - The new profile should include all entitlements from your entitlements file
   - Download and install

## 🔍 Why EventKit Doesn't Show in Xcode Capabilities

EventKit is **not a standard capability** like HealthKit or Push Notifications. It's an **entitlement** that:
- Must be declared in the entitlements file (✅ already done)
- Must be enabled in the App ID in Apple Developer portal
- Must be included in the provisioning profile

Unlike other capabilities, EventKit doesn't have a UI button in Xcode's "Signing & Capabilities" tab.

## 📋 Verification Checklist

After fixing:

- [ ] EventKit enabled in App ID (or using Automatic Signing)
- [ ] Provisioning profile regenerated
- [ ] New profile downloaded and installed
- [ ] Red error disappears in Xcode
- [ ] Project builds successfully
- [ ] App can request Reminders permission

## 🚀 Quick Fix (Recommended)

**Switch to Automatic Signing:**
1. Xcode → Signing & Capabilities
2. ✅ Check "Automatically manage signing"
3. Select Team: "STORI LLC"
4. Xcode handles everything automatically

This is the easiest solution and will resolve the issue immediately.

---

**Note:** EventKit entitlement is already in `AllTime.entitlements`. You just need the provisioning profile to include it, which Automatic Signing will handle automatically.

