# EventKit Reminders Integration

## Overview

This app integrates with iOS Reminders using **EventKit**, allowing users to sync reminders created in AllTime to the native iOS Reminders app.

## Important: No Entitlement Required

✅ **EventKit does NOT require a special entitlement or capability** in Xcode or the Apple Developer portal. The integration works with just:
- `NSCalendarsUsageDescription` in Info.plist
- `NSRemindersUsageDescription` in Info.plist
- Proper permission requests using `EKEventStore.requestAccess(to: .reminder)`

## Architecture

### Service Layer: `EventKitReminderManager`

**Location**: `AllTime/Services/EventKitReminderManager.swift`

A singleton service (`EventKitReminderManager.shared`) that handles:
- **Authorization**: Requests and checks reminder access permission
- **Calendar Management**: Creates/finds the "AllTime" reminder calendar
- **CRUD Operations**: Syncs reminders to/from iOS Reminders app
- **Error Handling**: Provides clear error messages

### Key Methods

```swift
// Request permission
let granted = await EventKitReminderManager.shared.requestAuthorization()

// Sync a reminder
try await EventKitReminderManager.shared.syncReminderToEventKit(reminder)

// Delete a reminder
try await EventKitReminderManager.shared.deleteReminderFromEventKit(reminderId: id)

// Fetch all reminders
let reminders = try await EventKitReminderManager.shared.fetchAllReminders()
```

### ViewModel Integration: `ReminderViewModel`

**Location**: `AllTime/ViewModels/ReminderViewModel.swift`

The `ReminderViewModel` automatically syncs reminders to EventKit when:
- Creating a new reminder (if `syncToEventKit` is true)
- Updating an existing reminder
- Completing a reminder
- Deleting a reminder

### UI Integration

The EventKit sync is optional and controlled by a toggle in:
- `CreateReminderView`: "Sync to iOS Reminders" toggle
- `EditReminderView`: Same toggle for editing

## Permission Flow

1. **First Launch**: User sees permission request when they try to sync a reminder
2. **Settings**: If denied, user can enable in Settings → Privacy & Security → Reminders
3. **Status Check**: `EventKitReminderManager.isAuthorized` reflects current permission status

## How It Works

### Reminder Identification

Each reminder synced to EventKit includes a unique marker in its notes:
```
[AllTime ID: 12345]
```

This allows the app to:
- Find existing reminders when updating
- Delete the correct reminder when needed
- Avoid duplicates

### Calendar Organization

All synced reminders are stored in a dedicated "AllTime" calendar in the iOS Reminders app, making them easy to identify and manage.

### Priority Mapping

AllTime priorities map to EKReminder priorities:
- `low` → 0 (None)
- `medium` → 1 (Low)
- `high` → 5 (Medium)
- `urgent` → 9 (High)

### Alarms

- If `reminderTime` is set, an alarm is created at that exact time
- Otherwise, a default alarm is set 15 minutes before the due date
- Completed reminders have no alarms

## Error Handling

The service throws `EventKitReminderError` with clear messages:
- `.notAuthorized`: Permission not granted
- `.calendarNotFound`: Could not create/find calendar
- `.saveFailed(String)`: Failed to save reminder
- `.deleteFailed(String)`: Failed to delete reminder

## Usage Example

```swift
// In a SwiftUI view
@StateObject private var eventKitManager = EventKitReminderManager.shared

// Request permission
Button("Enable Reminders") {
    Task {
        let granted = await eventKitManager.requestAuthorization()
        if granted {
            // Permission granted, can now sync reminders
        }
    }
}

// Sync a reminder
Task {
    do {
        try await eventKitManager.syncReminderToEventKit(reminder)
    } catch {
        print("Failed to sync: \(error.localizedDescription)")
    }
}
```

## Testing

1. **Permission Request**: 
   - Create a reminder with "Sync to iOS Reminders" enabled
   - Verify permission popup appears
   - Grant permission and verify reminder appears in iOS Reminders app

2. **Sync Operations**:
   - Create reminder → Check iOS Reminders app
   - Update reminder → Verify changes sync
   - Complete reminder → Verify completion syncs
   - Delete reminder → Verify deletion syncs

3. **Error Cases**:
   - Deny permission → Verify error handling
   - Delete app's reminder calendar → Verify recreation

## Files Modified

- ✅ `AllTime/Info.plist`: Added `NSCalendarsUsageDescription` and `NSRemindersUsageDescription`
- ✅ `AllTime/AllTime.entitlements`: **Removed** EventKit entitlement (not needed)
- ✅ `AllTime/Services/EventKitReminderManager.swift`: Refined and production-ready
- ✅ `AllTime/ViewModels/ReminderViewModel.swift`: Integrated EventKit sync
- ✅ `AllTime/Views/CreateReminderView.swift`: Added sync toggle
- ✅ `AllTime/Views/EditReminderView.swift`: Added sync toggle

## Notes

- EventKit integration is **optional** - users can use reminders without syncing to iOS Reminders
- The sync happens automatically when reminders are created/updated/deleted (if enabled)
- Reminders are stored in a dedicated "AllTime" calendar for easy identification
- No special provisioning profile or App ID configuration needed

