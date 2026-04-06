# STI Tracking Feature — Design Spec

**Date:** 2026-04-06  
**Status:** Approved

---

## Overview

Add STI test tracking to the Profile tab. Users can log test dates and results, set repeating reminders for future tests, and view a visual timeline of their test history. The existing single-date "last STI test" field in `UserProfile` is replaced by a proper test history stored in the database. The PrEP status row is removed entirely.

---

## Data Model

### `SQLSTITestResultType` — table: `stiTestResultType`

Mirrors the `activityType` / `protectionMethodType` pattern. Allows future user-customizable result types.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (TEXT) | Primary key |
| `name` | String | e.g. "Negative", "Positive", "Pending" |
| `icon` | String | SF Symbol name |
| `isBuiltIn` | Bool | Built-ins cannot be deleted |
| `isEnabled` | Bool | User can hide result types |
| `sortOrder` | Int | Display order |
| `dateAdded` | Date | Record creation timestamp |

**Built-in result types** (stable predefined UUIDs in the `00000000-0000-0000-0000-000000000003xx` range):

| UUID suffix | Name | Icon |
|---|---|---|
| `0301` | Negative | `checkmark.circle.fill` |
| `0302` | Positive | `exclamationmark.triangle.fill` |
| `0303` | Pending | `clock.fill` |

### `SQLSTITest` — table: `stiTest`

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (TEXT) | Primary key |
| `date` | Date | When the test was taken |
| `resultTypeId` | UUID (TEXT) | FK → `stiTestResultType.id` |
| `notes` | String | Optional free-text |
| `dateAdded` | Date | Record creation timestamp |

Foreign key: `resultTypeId` → `stiTestResultType(id)` with `ON DELETE RESTRICT` (result types with tests cannot be deleted).

---

## Database Migration

A new migration (Migration 9) performs the following:

1. Creates `stiTestResultType` table with the schema above.
2. Seeds the three built-in result types with their predefined UUIDs.
3. Creates `stiTest` table with the schema above, with a foreign key index on `resultTypeId`.
4. If `UserProfile.lastSTITestDate` (UserDefaults key `lastSTITestDate`) is non-nil at migration time, inserts a single `stiTest` record using that date with `resultTypeId` = Negative UUID and empty notes.
5. The `lastSTITestDate` UserDefaults key is cleared after migration. The `isOnPrep` UserDefaults key is also cleared.

---

## UserProfile Changes

The following fields are **removed** from `UserProfile`:
- `lastSTITestDate: Date?`
- `isOnPrep: Bool`
- `stiTestingIntervalDays: Int` — **added** (default: 90). Stores the user's preferred testing interval for reminder scheduling.
- `stiRemindersEnabled: Bool` — **added** (default: false). Whether local notification reminders are active.

`lastSTITestDate` becomes a computed property on `STIManager` derived from the most recent `SQLSTITest` record, not stored in `UserProfile`.

---

## Service Layer

### `STIService`

Registered as a `DependencyKey`. Follows `EncounterService` / `PartnerService` pattern. All multi-step writes use a single `database.write { db in }` block.

**Methods:**
- `fetchAll() -> [SQLSTITest]` — all tests sorted by `date` descending
- `fetchLatest() -> SQLSTITest?` — most recent test record
- `create(date:resultTypeId:notes:) throws -> UUID`
- `update(_ test: SQLSTITest) throws`
- `delete(_ id: UUID) throws`

### `STIResultTypeService`

Registered as a `DependencyKey`. Follows `CustomizationService` pattern.

**Methods:**
- `fetchAll() -> [SQLSTITestResultType]` — enabled types sorted by `sortOrder`
- `fetchAllIncludingDisabled() -> [SQLSTITestResultType]`
- `seedDefaults() throws` — idempotent seeding of the 3 built-in types
- `create(name:icon:) throws -> UUID` — user-defined types only
- `delete(_ id: UUID) throws` — only non-built-in types; errors if tests reference this type
- `toggle(_ id: UUID) throws` — enable/disable; updates directly in the same transaction

### `STIManager`

`@Observable` class, injected into the SwiftUI environment from `FuckifyApp`. Mirrors `EncountersManager` / `PartnersManager`.

**State:**
- `tests: [SQLSTITest]` — loaded via `@FetchAll` or manual fetch on appear
- `resultTypes: [SQLSTITestResultType]` — enabled types for pickers

**Computed:**
- `latestTest: SQLSTITest?` — first element of `tests`
- `nextTestDueDate: Date?` — `latestTest?.date + stiTestingIntervalDays`, nil if in the past
- `daysSinceLastTest: Int?`
- `daysUntilNextTest: Int?`

### `STIReminderService`

Methods on `STIManager` (or a private helper) using `UNUserNotificationCenter`. Notification identifier: `"sti-test-reminder"`.

**Behavior:**
- `scheduleReminder()` — cancels any existing `"sti-test-reminder"` notification, then schedules a new one at `nextTestDueDate` (or today + interval if no tests exist) with a fixed message: "Time for your STI test. Stay on top of your sexual health."
- `cancelReminder()` — removes `"sti-test-reminder"` from pending notifications.
- Called automatically after any `STIService` create/update/delete, and when `stiTestingIntervalDays` or `stiRemindersEnabled` changes.
- Before scheduling, checks `UNUserNotificationCenter` authorization status. If `.denied`, sets a `reminderDenied: Bool` flag on `STIManager` to drive the UI prompt.

---

## UI

### `ProfileView` — Health Check-In Section

The existing "Health Check-In" section (PrEP row, last test row, next test row) is **replaced entirely** with a single prominent STI Testing card. All `isOnPrep` / `editIsOnPrep` state and the PrEP edit toggle are removed.

**STI Testing card (view mode):**
- Full-width, padded card (not a row-style list item)
- Shows: last test date, result type badge (colored pill), "X days ago" status with color coding (green <90d, orange 90–180d, red >180d)
- Shows: "Next test due" date + "in X days" if applicable
- Chevron / "See All" button navigates to `STIHistoryView`
- Empty state: "No tests logged yet" with a prominent "Log First Test" button that opens `STITestFormView`

**Edit mode:** Edit mode in `ProfileView` no longer touches STI data. Tests are added/edited exclusively through `STIHistoryView` and `STITestFormView`.

### `STIHistoryView`

Pushed onto the `NavigationStack` from the STI card in `ProfileView`.

**Sections:**

1. **Summary header** — last test date + result badge + status color, next test due date + days countdown. Matches the card style from `ProfileView`.

2. **Reminders section** — segmented or stepper control for testing interval (30 / 60 / 90 / 180 days). Toggle to enable/disable reminders. If `reminderDenied` is true, shows inline prompt: "Notifications are disabled" with a "Open Settings" button linking to `UIApplication.openSettingsURLString`.

3. **Timeline** — vertical list of `SQLSTITest` records, newest first. Each row:
   - Colored dot (green = Negative, red = Positive, gray = Pending) connected by a vertical line to the next row
   - Date formatted as "Mar 12, 2025"
   - Result type name in a colored pill badge
   - Notes truncated to 1 line if present
   - Swipe-to-delete (with confirmation)
   - Tap navigates to `STITestDetailView`

4. **Empty state** (when no tests): centered illustration + "No tests logged yet" + "Log First Test" button

**Toolbar:** "+" button opens `STITestFormView` as a sheet.

### `STITestFormView`

Sheet for adding or editing a test. Fields:
- `DatePicker` for test date (in: ...Date())
- Result type picker — segmented control if ≤3 types, otherwise a `Menu` picker. Populated from `STIManager.resultTypes`. Shows error state if no enabled result types exist.
- `TextField` for optional notes

Toolbar: Cancel + Save buttons. Save is disabled if no result type is selected.

### `STITestDetailView`

Read view pushed from the timeline. Shows date, result type badge, notes. Toolbar "Edit" button enters inline edit mode (same pattern as `PartnerDetailView`). Edit mode shows the same fields as `STITestFormView` inline.

---

## Error Handling & Edge Cases

- **No tests logged** — card in `ProfileView` shows empty state. `STIHistoryView` shows empty state. No crash on nil `latestTest`.
- **Migration with nil `lastSTITestDate`** — no record is inserted; migration proceeds silently.
- **Migration with non-nil `lastSTITestDate`** — one record inserted with Negative result type; UserDefaults key cleared.
- **Notification permission denied** — `reminderDenied` flag drives an inline "Open Settings" prompt; no re-request.
- **Reminder with no test history** — scheduled from `Date() + stiTestingIntervalDays`.
- **Deleting the most recent test** — `STIManager` recomputes `latestTest` after delete; card and reminder update automatically.
- **Deleting a result type that has tests** — `STIResultTypeService.delete()` throws `STIResultTypeError.hasAssociatedTests`; UI shows an alert.
- **All result types disabled** — `STITestFormView` shows an inline error: "No result types available. Enable some in Settings."
- **Built-in result types** — cannot be deleted; only `isEnabled` and `sortOrder` can be modified.

---

## Files to Create

```
Fuckify/Features/STI/
├── Models/
│   ├── SQLSTITest.swift
│   └── SQLSTITestResultType.swift
├── Services/
│   ├── STIService.swift
│   └── STIResultTypeService.swift
├── ViewModels/
│   └── STIManager.swift
└── Views/
    ├── STIHistoryView.swift
    ├── STITestFormView.swift
    └── STITestDetailView.swift

Fuckify/Database/Migrations/
└── Migration9.swift
```

## Files to Modify

- `Fuckify/Database/AppDatabase.swift` — register Migration9
- `Fuckify/Features/Profile/ProfileView.swift` — replace Health Check-In section with STI card; remove PrEP/lastSTITestDate logic
- `Fuckify/Features/Profile/UserProfile.swift` — remove `lastSTITestDate`, `isOnPrep`; add `stiTestingIntervalDays`, `stiRemindersEnabled`
- `Fuckify/FuckifyApp.swift` — instantiate and inject `STIManager` into environment
