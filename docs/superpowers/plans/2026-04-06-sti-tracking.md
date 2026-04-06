# STI Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add STI test history tracking to the Profile tab with date/result logging, configurable reminders, and a vertical timeline view.

**Architecture:** New `SQLSTITestResultType` and `SQLSTITest` GRDB tables follow the existing `activityType`/`protectionMethodType` catalog pattern. A new `STIService` + `STIResultTypeService` handle all DB operations via the `Dependencies` library. A new `STIManager` (@Observable) drives all STI views and reminder scheduling. The Profile view's Health Check-In section is replaced with a single prominent STI card.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLiteData (GRDB), Dependencies (pointfree-co/swift-dependencies), UserNotifications

---

## File Map

**Create:**
- `Fuckify/Features/STI/Models/SQLSTITest.swift` — `SQLSTITest` + `SQLSTITestResultType` table structs and predefined UUIDs
- `Fuckify/Features/STI/Services/STIService.swift` — CRUD for `stiTest` table
- `Fuckify/Features/STI/Services/STIResultTypeService.swift` — CRUD + seeding for `stiTestResultType` table
- `Fuckify/Features/STI/ViewModels/STIManager.swift` — `@Observable` view model + reminder scheduling
- `Fuckify/Features/STI/Views/STIHistoryView.swift` — timeline + reminders section
- `Fuckify/Features/STI/Views/STITestFormView.swift` — add/edit sheet
- `Fuckify/Features/STI/Views/STITestDetailView.swift` — read/inline-edit detail view
- `Fuckify/Database/Migrations/AddSTITables.swift` — Migration 9

**Modify:**
- `Fuckify/Database/AppDatabase.swift` — register new migration
- `Fuckify/Features/Profile/UserProfile.swift` — remove `lastSTITestDate`/`isOnPrep`, add `stiTestingIntervalDays`/`stiRemindersEnabled`
- `Fuckify/Features/Profile/ProfileView.swift` — replace Health Check-In section with STI card
- `Fuckify/FuckifyApp.swift` — instantiate `STIManager` and inject into environment

---

## Task 1: Data Models

**Files:**
- Create: `Fuckify/Features/STI/Models/SQLSTITest.swift`

- [ ] **Step 1: Create the STI models file**

```swift
//
//  SQLSTITest.swift
//  Fuckify
//

import Foundation
import SwiftUI
import SQLiteData

// MARK: - STI Test Result Type (Catalog table — mirrors activityType pattern)

@Table("stiTestResultType")
struct SQLSTITestResultType: Identifiable {
    let id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var isBuiltIn: Bool     // true for built-ins, cannot be deleted
    var isEnabled: Bool     // visibility toggle
    var sortOrder: Int      // display ordering
    var dateAdded: Date

    nonisolated init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        isBuiltIn: Bool = false,
        isEnabled: Bool = true,
        sortOrder: Int = 0,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.dateAdded = dateAdded
    }
}

// MARK: - Predefined UUIDs for Built-in Result Types

extension SQLSTITestResultType {
    nonisolated static let negativeId = UUID(uuidString: "00000000-0000-0000-0000-000000000301")!
    nonisolated static let positiveId = UUID(uuidString: "00000000-0000-0000-0000-000000000302")!
    nonisolated static let pendingId  = UUID(uuidString: "00000000-0000-0000-0000-000000000303")!

    nonisolated static var builtIns: [SQLSTITestResultType] {
        [
            SQLSTITestResultType(
                id: negativeId,
                name: "Negative",
                icon: "checkmark.circle.fill",
                isBuiltIn: true,
                isEnabled: true,
                sortOrder: 0,
                dateAdded: Date()
            ),
            SQLSTITestResultType(
                id: positiveId,
                name: "Positive",
                icon: "exclamationmark.triangle.fill",
                isBuiltIn: true,
                isEnabled: true,
                sortOrder: 1,
                dateAdded: Date()
            ),
            SQLSTITestResultType(
                id: pendingId,
                name: "Pending",
                icon: "clock.fill",
                isBuiltIn: true,
                isEnabled: true,
                sortOrder: 2,
                dateAdded: Date()
            ),
        ]
    }

    /// Display color for this result type
    var displayColor: Color {
        switch id {
        case SQLSTITestResultType.negativeId: return .green
        case SQLSTITestResultType.positiveId: return .red
        default: return .gray
        }
    }
}

// MARK: - STI Test Record

@Table("stiTest")
struct SQLSTITest: Identifiable {
    let id: UUID
    var date: Date
    var resultTypeId: UUID  // FK → stiTestResultType.id
    var notes: String
    var dateAdded: Date

    nonisolated init(
        id: UUID = UUID(),
        date: Date,
        resultTypeId: UUID,
        notes: String = "",
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.resultTypeId = resultTypeId
        self.notes = notes
        self.dateAdded = dateAdded
    }
}
```

- [ ] **Step 2: Build the project to verify models compile**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED (or only pre-existing errors unrelated to the new file)

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/Models/SQLSTITest.swift
git commit -m "feat(sti): add SQLSTITest and SQLSTITestResultType models"
```

---

## Task 2: Database Migration

**Files:**
- Create: `Fuckify/Database/Migrations/AddSTITables.swift`
- Modify: `Fuckify/Database/AppDatabase.swift`

- [ ] **Step 1: Create the migration file**

```swift
//
//  AddSTITables.swift
//  Fuckify
//
//  Migration 9: Add STI test tracking tables and migrate existing lastSTITestDate
//

import Foundation
import SQLiteData
import GRDB

struct AddSTITables {
    nonisolated static func migrate(_ db: Database) throws {
        // 1. Create stiTestResultType table (catalog — mirrors activityType)
        try db.execute(sql: """
            CREATE TABLE "stiTestResultType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)

        // 2. Seed built-in result types
        let negativeId = "00000000-0000-0000-0000-000000000301"
        let positiveId = "00000000-0000-0000-0000-000000000302"
        let pendingId  = "00000000-0000-0000-0000-000000000303"
        let now = ISO8601DateFormatter().string(from: Date())

        try db.execute(sql: """
            INSERT INTO "stiTestResultType" ("id","name","icon","isBuiltIn","isEnabled","sortOrder","dateAdded")
            VALUES
                ('\(negativeId)', 'Negative', 'checkmark.circle.fill',    1, 1, 0, '\(now)'),
                ('\(positiveId)', 'Positive', 'exclamationmark.triangle.fill', 1, 1, 1, '\(now)'),
                ('\(pendingId)',  'Pending',  'clock.fill',               1, 1, 2, '\(now)')
        """)

        // 3. Create stiTest table
        try db.execute(sql: """
            CREATE TABLE "stiTest"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "date" TEXT NOT NULL,
                "resultTypeId" TEXT NOT NULL,
                "notes" TEXT NOT NULL,
                "dateAdded" TEXT NOT NULL,
                FOREIGN KEY ("resultTypeId") REFERENCES "stiTestResultType"("id") ON DELETE RESTRICT
            ) STRICT
        """)

        // 4. Index on resultTypeId for FK performance
        try db.execute(sql: """
            CREATE INDEX "idx_stiTest_resultTypeId" ON "stiTest"("resultTypeId")
        """)

        // 5. Migrate existing lastSTITestDate from UserDefaults → first stiTest record
        if let existingDate = UserDefaults.standard.object(forKey: "userLastSTITestDate") as? Date {
            let dateStr = ISO8601DateFormatter().string(from: existingDate)
            let recordId = UUID().uuidString
            try db.execute(sql: """
                INSERT INTO "stiTest" ("id","date","resultTypeId","notes","dateAdded")
                VALUES ('\(recordId)', '\(dateStr)', '\(negativeId)', '', '\(now)')
            """)
        }

        // 6. Clear migrated UserDefaults keys
        UserDefaults.standard.removeObject(forKey: "userLastSTITestDate")
        UserDefaults.standard.removeObject(forKey: "userIsOnPrep")
    }
}
```

- [ ] **Step 2: Register migration in AppDatabase.swift**

In `Fuckify/Database/AppDatabase.swift`, after the last `registerMigration` call (after "Update partner last encounter date"), add:

```swift
    migrator.registerMigration("Add STI tables") { db in
        try AddSTITables.migrate(db)
    }
```

- [ ] **Step 3: Build to verify migration compiles**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Database/Migrations/AddSTITables.swift Fuckify/Database/AppDatabase.swift
git commit -m "feat(sti): add migration 9 — create stiTestResultType and stiTest tables"
```

---

## Task 3: STIResultTypeService

**Files:**
- Create: `Fuckify/Features/STI/Services/STIResultTypeService.swift`

- [ ] **Step 1: Create STIResultTypeService**

```swift
//
//  STIResultTypeService.swift
//  Fuckify
//
//  Service for managing STI test result type catalog (mirrors CustomizationService pattern)
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "STIResultTypeService")

enum STIResultTypeError: LocalizedError {
    case cannotDeleteBuiltIn
    case hasAssociatedTests

    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            return "Built-in result types cannot be deleted. You can disable them instead."
        case .hasAssociatedTests:
            return "This result type has associated tests and cannot be deleted."
        }
    }
}

struct STIResultTypeService {
    @Dependency(\.defaultDatabase) var database

    nonisolated init() {}

    // MARK: - Read

    /// Fetch all enabled result types sorted by sortOrder
    func fetchAll() throws -> [SQLSTITestResultType] {
        try database.read { db in
            try SQLSTITestResultType
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    /// Fetch all result types including disabled ones
    func fetchAllIncludingDisabled() throws -> [SQLSTITestResultType] {
        try database.read { db in
            try SQLSTITestResultType
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    // MARK: - Create

    /// Create a new custom result type
    func create(name: String, icon: String) throws -> UUID {
        try database.write { db in
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM stiTestResultType"
            ) ?? 0

            let entity = SQLSTITestResultType(
                id: UUID(),
                name: name,
                icon: icon,
                isBuiltIn: false,
                isEnabled: true,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date()
            )

            try SQLSTITestResultType.insert { entity }.execute(db)
            logger.info("Created STI result type: \(entity.id)")
            return entity.id
        }
    }

    // MARK: - Delete

    /// Delete a custom result type. Throws if built-in or has associated tests.
    func delete(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLSTITestResultType.find(id).fetchOne(db) else { return }

            if entity.isBuiltIn {
                logger.warning("Attempted to delete built-in STI result type: \(id)")
                throw STIResultTypeError.cannotDeleteBuiltIn
            }

            // Check if any stiTest records reference this type
            let count = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM stiTest WHERE resultTypeId = ?",
                arguments: [id.uuidString]
            ) ?? 0

            if count > 0 {
                throw STIResultTypeError.hasAssociatedTests
            }

            try SQLSTITestResultType
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted STI result type: \(id)")
        }
    }

    // MARK: - Toggle

    /// Toggle enabled status. Updates directly in the same transaction.
    func toggle(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLSTITestResultType.find(id).fetchOne(db) else { return }
            var updated = entity
            updated.isEnabled.toggle()

            if updated.isBuiltIn {
                try db.execute(
                    sql: "UPDATE stiTestResultType SET isEnabled = ?, sortOrder = ? WHERE id = ?",
                    arguments: [updated.isEnabled, updated.sortOrder, updated.id.uuidString]
                )
            } else {
                try SQLSTITestResultType.update(updated).execute(db)
            }
            logger.info("Toggled STI result type \(id): isEnabled=\(updated.isEnabled)")
        }
    }

    // MARK: - Seed

    /// Idempotent seeding of the 3 built-in result types
    func seedDefaults() throws {
        try database.write { db in
            for resultType in SQLSTITestResultType.builtIns {
                let existing = try SQLSTITestResultType.find(resultType.id).fetchOne(db)
                if existing == nil {
                    try SQLSTITestResultType.insert { resultType }.execute(db)
                }
            }
        }
    }
}

// MARK: - Dependency Key

extension STIResultTypeService: DependencyKey {
    nonisolated static var liveValue: STIResultTypeService { STIResultTypeService() }
}

extension DependencyValues {
    var stiResultTypeService: STIResultTypeService {
        get { self[STIResultTypeService.self] }
        set { self[STIResultTypeService.self] = newValue }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/Services/STIResultTypeService.swift
git commit -m "feat(sti): add STIResultTypeService"
```

---

## Task 4: STIService

**Files:**
- Create: `Fuckify/Features/STI/Services/STIService.swift`

- [ ] **Step 1: Create STIService**

```swift
//
//  STIService.swift
//  Fuckify
//
//  Service layer for STI test CRUD operations (mirrors PartnerService pattern)
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "STIService")

struct STIService {
    @Dependency(\.defaultDatabase) var database

    nonisolated init() {}

    // MARK: - Read

    /// Fetch all STI tests sorted by date descending (newest first)
    func fetchAll() throws -> [SQLSTITest] {
        try database.read { db in
            try SQLSTITest
                .order { $0.date.desc() }
                .fetchAll(db)
        }
    }

    /// Fetch the most recent STI test
    func fetchLatest() throws -> SQLSTITest? {
        try database.read { db in
            try SQLSTITest
                .order { $0.date.desc() }
                .fetchOne(db)
        }
    }

    // MARK: - Create

    /// Create a new STI test record and return its ID
    func create(date: Date, resultTypeId: UUID, notes: String) throws -> UUID {
        try database.write { db in
            let test = SQLSTITest(
                id: UUID(),
                date: date,
                resultTypeId: resultTypeId,
                notes: notes,
                dateAdded: Date()
            )
            try SQLSTITest.insert { test }.execute(db)
            logger.info("Created STI test: \(test.id)")
            return test.id
        }
    }

    // MARK: - Update

    /// Update an existing STI test record
    func update(_ test: SQLSTITest) throws {
        try database.write { db in
            try SQLSTITest.update(test).execute(db)
            logger.info("Updated STI test: \(test.id)")
        }
    }

    // MARK: - Delete

    /// Delete a STI test record by ID
    func delete(_ id: UUID) throws {
        try database.write { db in
            try SQLSTITest
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted STI test: \(id)")
        }
    }
}

// MARK: - Dependency Key

extension STIService: DependencyKey {
    nonisolated static var liveValue: STIService { STIService() }
}

extension DependencyValues {
    var stiService: STIService {
        get { self[STIService.self] }
        set { self[STIService.self] = newValue }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/Services/STIService.swift
git commit -m "feat(sti): add STIService"
```

---

## Task 5: STIManager

**Files:**
- Create: `Fuckify/Features/STI/ViewModels/STIManager.swift`

- [ ] **Step 1: Create STIManager**

```swift
//
//  STIManager.swift
//  Fuckify
//
//  Observable view model for STI test tracking. Mirrors EncountersViewModel pattern.
//

import Foundation
import UserNotifications
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "STIManager")

private let reminderNotificationId = "sti-test-reminder"

@MainActor
@Observable
final class STIManager {
    // MARK: - Dependencies

    private let stiService: STIService
    private let stiResultTypeService: STIResultTypeService

    // MARK: - State

    var tests: [SQLSTITest] = []
    var resultTypes: [SQLSTITestResultType] = []
    var errorMessage: String?
    var reminderDenied: Bool = false

    // MARK: - Computed Properties

    var latestTest: SQLSTITest? { tests.first }

    var daysSinceLastTest: Int? {
        guard let latest = latestTest else { return nil }
        return Calendar.current.dateComponents([.day], from: latest.date, to: Date()).day
    }

    var nextTestDueDate: Date? {
        let interval = UserDefaults.standard.integer(forKey: "stiTestingIntervalDays")
        let days = interval > 0 ? interval : 90
        guard let latest = latestTest else {
            // No tests — schedule from today
            return Calendar.current.date(byAdding: .day, value: days, to: Date())
        }
        let candidate = Calendar.current.date(byAdding: .day, value: days, to: latest.date)
        guard let c = candidate, c > Date() else { return nil }
        return c
    }

    var daysUntilNextTest: Int? {
        guard let next = nextTestDueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: next).day
    }

    /// Color for "days since last test" status (matches existing ProfileView logic)
    var statusColor: Color {
        guard let days = daysSinceLastTest else { return .red }
        if days < 90 { return .green }
        if days < 180 { return .orange }
        return .red
    }

    var statusIcon: String {
        guard let days = daysSinceLastTest else { return "exclamationmark.triangle.fill" }
        if days < 90 { return "checkmark.circle.fill" }
        if days < 180 { return "exclamationmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    // MARK: - Init

    nonisolated init(
        stiService: STIService = STIService(),
        stiResultTypeService: STIResultTypeService = STIResultTypeService()
    ) {
        self.stiService = stiService
        self.stiResultTypeService = stiResultTypeService
    }

    // MARK: - Data Operations

    func load() async {
        do {
            tests = try stiService.fetchAll()
            resultTypes = try stiResultTypeService.fetchAll()
        } catch {
            logger.error("Failed to load STI data: \(error.localizedDescription)")
            errorMessage = "Unable to load STI test history."
        }
    }

    func addTest(date: Date, resultTypeId: UUID, notes: String) async {
        do {
            _ = try stiService.create(date: date, resultTypeId: resultTypeId, notes: notes)
            await load()
            await rescheduleReminderIfEnabled()
        } catch {
            logger.error("Failed to create STI test: \(error.localizedDescription)")
            errorMessage = "Unable to save test. Please try again."
        }
    }

    func updateTest(_ test: SQLSTITest) async {
        do {
            try stiService.update(test)
            await load()
            await rescheduleReminderIfEnabled()
        } catch {
            logger.error("Failed to update STI test: \(error.localizedDescription)")
            errorMessage = "Unable to update test. Please try again."
        }
    }

    func deleteTest(_ id: UUID) async {
        do {
            try stiService.delete(id)
            await load()
            await rescheduleReminderIfEnabled()
        } catch {
            logger.error("Failed to delete STI test: \(error.localizedDescription)")
            errorMessage = "Unable to delete test. Please try again."
        }
    }

    // MARK: - Reminders

    /// Call when user toggles reminders on. Checks permission, schedules if granted.
    func enableReminders() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            reminderDenied = true
            logger.warning("Notification permission denied — cannot schedule STI reminder")
        case .authorized, .provisional, .ephemeral:
            reminderDenied = false
            await scheduleReminder()
        case .notDetermined:
            // Should not happen — permission already requested at app launch
            // Attempt to schedule anyway; system will silently drop if not granted
            await scheduleReminder()
        @unknown default:
            await scheduleReminder()
        }
    }

    func disableReminders() async {
        await cancelReminder()
    }

    func rescheduleReminderIfEnabled() async {
        let remindersEnabled = UserDefaults.standard.bool(forKey: "stiRemindersEnabled")
        if remindersEnabled {
            await enableReminders()
        }
    }

    private func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])

        let interval = UserDefaults.standard.integer(forKey: "stiTestingIntervalDays")
        let days = interval > 0 ? interval : 90

        let fireDate: Date
        if let latest = latestTest {
            guard let candidate = Calendar.current.date(byAdding: .day, value: days, to: latest.date),
                  candidate > Date() else {
                // Due date already passed — schedule from today
                fireDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
                return scheduleNotification(at: fireDate, center: center)
            }
            fireDate = candidate
        } else {
            fireDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
        }

        scheduleNotification(at: fireDate, center: center)
    }

    private func scheduleNotification(at date: Date, center: UNUserNotificationCenter) {
        let content = UNMutableNotificationContent()
        content.title = "STI Test Reminder"
        content.body = "Time for your STI test. Stay on top of your sexual health."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: reminderNotificationId, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                logger.error("Failed to schedule STI reminder: \(error.localizedDescription)")
            } else {
                logger.info("Scheduled STI reminder for \(date)")
            }
        }
    }

    private func cancelReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])
        logger.info("Cancelled STI reminder")
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/ViewModels/STIManager.swift
git commit -m "feat(sti): add STIManager observable view model with reminder scheduling"
```

---

## Task 6: UserProfile Changes

**Files:**
- Modify: `Fuckify/Features/Profile/UserProfile.swift`

- [ ] **Step 1: Update UserProfile — remove old fields, add new ones**

Replace the entire contents of `UserProfile.swift` with:

```swift
//
//  UserProfile.swift
//  Fuckify
//
//  User profile data model with proper observation support.
//  Uses stored properties with didSet observers for proper SwiftUI observation.
//

import Foundation
import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "UserProfile")

/// User profile information stored in UserDefaults.
@MainActor
@Observable
final class UserProfile {
    // MARK: - Stored Properties

    var name: String {
        didSet {
            UserDefaults.standard.set(name, forKey: "userName")
            lastModified = Date()
        }
    }

    var dateOfBirth: Date? {
        didSet {
            if let date = dateOfBirth {
                UserDefaults.standard.set(date, forKey: "userDateOfBirth")
            } else {
                UserDefaults.standard.removeObject(forKey: "userDateOfBirth")
            }
            lastModified = Date()
        }
    }

    var notes: String {
        didSet {
            UserDefaults.standard.set(notes, forKey: "userNotes")
            lastModified = Date()
        }
    }

    var lastModified: Date {
        didSet {
            UserDefaults.standard.set(lastModified, forKey: "userLastModified")
        }
    }

    /// Testing interval in days for STI reminders (default: 90)
    var stiTestingIntervalDays: Int {
        didSet {
            UserDefaults.standard.set(stiTestingIntervalDays, forKey: "stiTestingIntervalDays")
        }
    }

    /// Whether STI test reminders are enabled
    var stiRemindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(stiRemindersEnabled, forKey: "stiRemindersEnabled")
        }
    }

    // MARK: - Initialization

    init() {
        self.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.dateOfBirth = UserDefaults.standard.object(forKey: "userDateOfBirth") as? Date
        self.notes = UserDefaults.standard.string(forKey: "userNotes") ?? ""
        self.lastModified = UserDefaults.standard.object(forKey: "userLastModified") as? Date ?? Date()
        let interval = UserDefaults.standard.integer(forKey: "stiTestingIntervalDays")
        self.stiTestingIntervalDays = interval > 0 ? interval : 90
        self.stiRemindersEnabled = UserDefaults.standard.bool(forKey: "stiRemindersEnabled")
    }

    // MARK: - Computed Properties

    var age: Int? {
        guard let dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dateOfBirth, to: Date()).year
    }

    var initials: String { name.initials }

    var hasProfile: Bool { !name.isEmpty }

    func clearProfile() {
        logger.info("Clearing user profile")
        name = ""
        dateOfBirth = nil
        notes = ""
        stiTestingIntervalDays = 90
        stiRemindersEnabled = false
    }
}
```

- [ ] **Step 2: Build to verify — expect compiler errors in ProfileView due to removed fields**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: Errors in `ProfileView.swift` referencing `isOnPrep`, `lastSTITestDate`, `editIsOnPrep`, `editShowLastSTITestDate`, `editLastSTITestDate`. These are fixed in Task 7.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Profile/UserProfile.swift
git commit -m "feat(sti): update UserProfile — remove isOnPrep/lastSTITestDate, add stiTestingIntervalDays/stiRemindersEnabled"
```

---

## Task 7: Inject STIManager into App

**Files:**
- Modify: `Fuckify/FuckifyApp.swift`

- [ ] **Step 1: Add STIManager state and environment injection**

In `FuckifyApp`, add the `@State` property after `liveActivityManager`:

```swift
@State private var stiManager = STIManager()
```

Then in the `ContentView()` environment modifiers chain (after `.environment(liveActivityManager)`), add:

```swift
.environment(stiManager)
```

Also add it to `OnboardingView()` if needed (no — onboarding does not use STI). Only inject into `ContentView`.

The full `body` scene block around ContentView should look like:

```swift
ContentView()
    .environment(securitySettings)
    .environment(userProfile)
    .environment(userSettings)
    .environment(liveActivityManager)
    .environment(stiManager)
    .environment(\.appIsLocked, securitySettings.isSecurityEnabled && !isUnlocked)
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: Same ProfileView errors from Task 6. No new errors.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/FuckifyApp.swift
git commit -m "feat(sti): inject STIManager into SwiftUI environment"
```

---

## Task 8: STITestFormView

**Files:**
- Create: `Fuckify/Features/STI/Views/STITestFormView.swift`

- [ ] **Step 1: Create STITestFormView**

```swift
//
//  STITestFormView.swift
//  Fuckify
//
//  Sheet for adding or editing an STI test record.
//

import SwiftUI

struct STITestFormView: View {
    @Environment(STIManager.self) private var stiManager
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing test to edit; nil to create new
    var existingTest: SQLSTITest? = nil

    @State private var date: Date = Date()
    @State private var selectedResultTypeId: UUID? = nil
    @State private var notes: String = ""
    @State private var isSaving = false

    private var isEditing: Bool { existingTest != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Date") {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                Section("Result") {
                    if stiManager.resultTypes.isEmpty {
                        Text("No result types available. Enable some in Settings.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if stiManager.resultTypes.count <= 3 {
                        // Segmented picker for ≤3 options
                        Picker("Result", selection: $selectedResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Text(type.name).tag(Optional(type.id))
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        // Menu picker for >3 options
                        Picker("Result", selection: $selectedResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Label(type.name, systemImage: type.icon).tag(Optional(type.id))
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Test" : "Log STI Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedResultTypeId == nil || isSaving)
                }
            }
            .onAppear {
                if let test = existingTest {
                    date = test.date
                    selectedResultTypeId = test.resultTypeId
                    notes = test.notes
                } else {
                    // Default to first enabled result type
                    selectedResultTypeId = stiManager.resultTypes.first?.id
                }
            }
        }
    }

    private func save() {
        guard let resultTypeId = selectedResultTypeId else { return }
        isSaving = true
        Task {
            if let test = existingTest {
                var updated = test
                updated.date = date
                updated.resultTypeId = resultTypeId
                updated.notes = notes
                await stiManager.updateTest(updated)
            } else {
                await stiManager.addTest(date: date, resultTypeId: resultTypeId, notes: notes)
            }
            dismiss()
        }
    }
}

#Preview {
    STITestFormView()
        .environment(STIManager())
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: Same ProfileView errors from Task 6 only. No new errors from STITestFormView.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/Views/STITestFormView.swift
git commit -m "feat(sti): add STITestFormView sheet"
```

---

## Task 9: STITestDetailView

**Files:**
- Create: `Fuckify/Features/STI/Views/STITestDetailView.swift`

- [ ] **Step 1: Create STITestDetailView**

```swift
//
//  STITestDetailView.swift
//  Fuckify
//
//  Detail view for a single STI test. Supports inline editing (mirrors PartnerDetailView pattern).
//

import SwiftUI

struct STITestDetailView: View {
    let test: SQLSTITest

    @Environment(STIManager.self) private var stiManager
    @Environment(\.editMode) private var editMode

    @State private var editDate: Date = Date()
    @State private var editResultTypeId: UUID? = nil
    @State private var editNotes: String = ""
    @State private var showingDeleteConfirm = false
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    private var resultType: SQLSTITestResultType? {
        stiManager.resultTypes.first { $0.id == test.resultTypeId }
            ?? stiManager.resultTypes.first(where: { _ in true }) // fallback for disabled types
    }

    var body: some View {
        List {
            Section("Test Date") {
                if isEditing {
                    DatePicker(
                        "Date",
                        selection: $editDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                } else {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(test.date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Result") {
                if isEditing {
                    if stiManager.resultTypes.count <= 3 {
                        Picker("Result", selection: $editResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Text(type.name).tag(Optional(type.id))
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Picker("Result", selection: $editResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Label(type.name, systemImage: type.icon).tag(Optional(type.id))
                            }
                        }
                    }
                } else {
                    if let rt = resultType {
                        HStack {
                            Image(systemName: rt.icon)
                                .foregroundStyle(rt.displayColor)
                            Text(rt.name)
                                .fontWeight(.medium)
                                .foregroundStyle(rt.displayColor)
                        }
                    }
                }
            }

            Section("Notes") {
                if isEditing {
                    TextField("Optional notes", text: $editNotes, axis: .vertical)
                        .lineLimit(3...6)
                } else if test.notes.isEmpty {
                    Text("No notes")
                        .foregroundStyle(.secondary)
                } else {
                    Text(test.notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(test.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            if newValue?.isEditing == true {
                editDate = test.date
                editResultTypeId = test.resultTypeId
                editNotes = test.notes
            } else if newValue?.isEditing == false {
                saveIfChanged()
            }
        }
    }

    private func saveIfChanged() {
        guard let resultTypeId = editResultTypeId else { return }
        var updated = test
        updated.date = editDate
        updated.resultTypeId = resultTypeId
        updated.notes = editNotes
        Task { await stiManager.updateTest(updated) }
    }
}

#Preview {
    NavigationStack {
        STITestDetailView(
            test: SQLSTITest(
                id: UUID(),
                date: Date(),
                resultTypeId: SQLSTITestResultType.negativeId,
                notes: "All clear"
            )
        )
        .environment(STIManager())
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: Same pre-existing ProfileView errors only.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/Views/STITestDetailView.swift
git commit -m "feat(sti): add STITestDetailView with inline edit"
```

---

## Task 10: STIHistoryView

**Files:**
- Create: `Fuckify/Features/STI/Views/STIHistoryView.swift`

- [ ] **Step 1: Create STIHistoryView**

```swift
//
//  STIHistoryView.swift
//  Fuckify
//
//  Full STI test history with timeline, reminders section, and summary header.
//

import SwiftUI

struct STIHistoryView: View {
    @Environment(STIManager.self) private var stiManager
    @Environment(UserProfile.self) private var profile

    @State private var showingAddForm = false
    @State private var testToDelete: SQLSTITest? = nil
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            // Summary Header
            summaryHeaderSection

            // Reminders Section
            remindersSection

            // Timeline or Empty State
            if stiManager.tests.isEmpty {
                emptyStateSection
            } else {
                timelineSection
            }
        }
        .navigationTitle("STI Test History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Test", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            STITestFormView()
                .dismissOnAppLock()
        }
        .alert("Delete Test", isPresented: $showingDeleteAlert, presenting: testToDelete) { test in
            Button("Delete", role: .destructive) {
                Task { await stiManager.deleteTest(test.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { test in
            Text("Delete the test from \(test.date.formatted(date: .abbreviated, time: .omitted))?")
        }
        .task { await stiManager.load() }
    }

    // MARK: - Summary Header

    private var summaryHeaderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if let latest = stiManager.latestTest {
                    HStack {
                        Label("Last Test", systemImage: stiManager.statusIcon)
                            .foregroundStyle(stiManager.statusColor)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.medium)
                            if let days = stiManager.daysSinceLastTest {
                                Text("\(days) days ago")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let nextDate = stiManager.nextTestDueDate, let daysUntil = stiManager.daysUntilNextTest {
                        Divider()
                        HStack {
                            Label("Next Test Due", systemImage: "bell.badge")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.medium)
                                Text("in \(daysUntil) days")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                } else {
                    HStack {
                        Label("No tests logged yet", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Reminders Section

    @ViewBuilder
    private var remindersSection: some View {
        @Bindable var bindableProfile = profile

        Section("Reminders") {
            Toggle("Test Reminders", isOn: Binding(
                get: { profile.stiRemindersEnabled },
                set: { enabled in
                    profile.stiRemindersEnabled = enabled
                    Task {
                        if enabled {
                            await stiManager.enableReminders()
                        } else {
                            await stiManager.disableReminders()
                        }
                    }
                }
            ))

            if profile.stiRemindersEnabled {
                Picker("Testing Interval", selection: $bindableProfile.stiTestingIntervalDays) {
                    Text("Every 30 days").tag(30)
                    Text("Every 60 days").tag(60)
                    Text("Every 90 days").tag(90)
                    Text("Every 180 days").tag(180)
                }
                .onChange(of: profile.stiTestingIntervalDays) { _, _ in
                    Task { await stiManager.rescheduleReminderIfEnabled() }
                }
            }

            if stiManager.reminderDenied {
                HStack {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications Disabled")
                            .fontWeight(.medium)
                        Text("Enable notifications in Settings to receive reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        Section("Test History") {
            ForEach(Array(stiManager.tests.enumerated()), id: \.element.id) { index, test in
                NavigationLink(destination: STITestDetailView(test: test)) {
                    TimelineRowView(
                        test: test,
                        resultType: stiManager.resultTypes.first { $0.id == test.resultTypeId },
                        isLast: index == stiManager.tests.count - 1
                    )
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        testToDelete = test
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "cross.case")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue.opacity(0.5))
                Text("No tests logged yet")
                    .font(.headline)
                Text("Log your STI tests to track your sexual health history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showingAddForm = true
                } label: {
                    Label("Log First Test", systemImage: "plus.circle.fill")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Timeline Row

private struct TimelineRowView: View {
    let test: SQLSTITest
    let resultType: SQLSTITestResultType?
    let isLast: Bool

    var dotColor: Color {
        resultType?.displayColor ?? .gray
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Dot + vertical line
            VStack(spacing: 0) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(test.date.formatted(date: .abbreviated, time: .omitted))
                    .fontWeight(.medium)
                if let rt = resultType {
                    Label(rt.name, systemImage: rt.icon)
                        .font(.caption)
                        .foregroundStyle(rt.displayColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(dotColor.opacity(0.12), in: Capsule())
                }
                if !test.notes.isEmpty {
                    Text(test.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    NavigationStack {
        STIHistoryView()
            .environment(STIManager())
            .environment(UserProfile())
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|BUILD"
```

Expected: Same pre-existing ProfileView errors only.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/STI/Views/STIHistoryView.swift
git commit -m "feat(sti): add STIHistoryView with vertical timeline and reminders"
```

---

## Task 11: Update ProfileView

**Files:**
- Modify: `Fuckify/Features/Profile/ProfileView.swift`

This is the task that fixes all remaining compiler errors from Task 6.

- [ ] **Step 1: Replace ProfileView.swift contents**

Replace the entire file with:

```swift
//
//  ProfileView.swift
//  Fuckify
//

import SwiftUI

struct ProfileView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(STIManager.self) private var stiManager
    @State private var showingSettings = false
    @State private var showingSTIForm = false
    @State private var isEditing = false

    // Editable fields
    @State private var editName: String = ""
    @State private var editDateOfBirth: Date?
    @State private var editShowDateOfBirth: Bool = false
    @State private var editNotes: String = ""

    private var hasProfileData: Bool {
        !profile.name.isEmpty || profile.dateOfBirth != nil || !profile.notes.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // Avatar Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color("AccentColor"))
                                    .frame(width: 100, height: 100)
                                Text(isEditing ? editName.initials : profile.initials)
                                    .font(.system(.largeTitle, weight: .bold))
                                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                    .foregroundColor(.white)
                            }
                            if !isEditing {
                                Text(profile.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let age = profile.age {
                                    Text("\(age) years old")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // Basic Information (edit mode only)
                if isEditing {
                    Section("Basic Information") {
                        TextField("Name", text: $editName)
                            .textContentType(.name)
                        Toggle("Date of Birth", isOn: $editShowDateOfBirth)
                        if editShowDateOfBirth {
                            DatePicker(
                                "Date",
                                selection: Binding(
                                    get: { editDateOfBirth ?? Date() },
                                    set: { editDateOfBirth = $0 }
                                ),
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    }
                }

                // STI Testing Card
                Section("Sexual Health") {
                    STITestingCard(showingAddForm: $showingSTIForm)
                }

                // Notes Section
                Section("Notes") {
                    if isEditing {
                        TextEditor(text: $editNotes)
                            .frame(minHeight: 100)
                    } else if !profile.notes.isEmpty {
                        Text(profile.notes)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No notes")
                            .foregroundColor(.secondary)
                    }
                }

                // Last Updated
                if !isEditing && hasProfileData {
                    Section {
                        HStack {
                            Spacer()
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Last updated: \(profile.lastModified.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(nil, value: isEditing)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditing {
                        Button {
                            withAnimation { isEditing = true }
                        } label: {
                            Text("Edit")
                        }
                    } else {
                        if #available(iOS 26.0, *) {
                            Button {
                                withAnimation { isEditing = false }
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .buttonStyle(.glassProminent)
                        } else {
                            Button {
                                withAnimation { isEditing = false }
                            } label: {
                                Text("Done")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !isEditing {
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        .animation(nil, value: isEditing)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().dismissOnAppLock()
            }
            .sheet(isPresented: $showingSTIForm) {
                STITestFormView().dismissOnAppLock()
            }
            .onAppear { loadEditableFields() }
            .onChange(of: isEditing) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    saveChanges()
                } else if oldValue == false && newValue == true {
                    loadEditableFields()
                }
            }
        }
    }

    private func loadEditableFields() {
        editName = profile.name
        editDateOfBirth = profile.dateOfBirth
        editShowDateOfBirth = profile.dateOfBirth != nil
        editNotes = profile.notes
    }

    private func saveChanges() {
        profile.name = editName
        profile.dateOfBirth = editShowDateOfBirth ? editDateOfBirth : nil
        profile.notes = editNotes
    }
}

// MARK: - STI Testing Card

private struct STITestingCard: View {
    @Environment(STIManager.self) private var stiManager
    @Binding var showingAddForm: Bool

    var body: some View {
        if stiManager.tests.isEmpty {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "cross.case")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.opacity(0.5))
                Text("Track Your STI Tests")
                    .font(.headline)
                Text("Log your test dates and results to stay on top of your sexual health.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showingAddForm = true
                } label: {
                    Label("Log First Test", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        } else {
            // Summary card with navigation link to history
            NavigationLink(destination: STIHistoryView()) {
                VStack(alignment: .leading, spacing: 12) {
                    // Last test row
                    HStack {
                        Label("Last STI Test", systemImage: stiManager.statusIcon)
                        Spacer()
                        if let days = stiManager.daysSinceLastTest,
                           let latest = stiManager.latestTest {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.medium)
                                Text("\(days) days ago")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(stiManager.statusColor)

                    // Next test due row
                    if let nextDate = stiManager.nextTestDueDate,
                       let daysUntil = stiManager.daysUntilNextTest {
                        Divider()
                        HStack {
                            Label("Next Test Due", systemImage: "bell.badge")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.medium)
                                Text("in \(daysUntil) days")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(UserProfile())
        .environment(STIManager())
}
```

- [ ] **Step 2: Build — expect BUILD SUCCEEDED with no errors**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Profile/ProfileView.swift
git commit -m "feat(sti): update ProfileView — replace Health Check-In with STI card"
```

---

## Task 12: Load STIManager Data on App Start

**Files:**
- Modify: `Fuckify/FuckifyApp.swift`

The `STIManager` needs to load its data when the app launches and load the result types once the environment is ready.

- [ ] **Step 1: Add `.task` to load STIManager after ContentView appears**

In `FuckifyApp.body`, on the `ContentView()` chain (after the `.environment` modifiers), add:

```swift
.task {
    await stiManager.load()
}
```

Place it after `.environment(\.appIsLocked, ...)` and before `.onShake`.

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fuckify/FuckifyApp.swift
git commit -m "feat(sti): load STIManager data on app start"
```

---

## Task 13: Manual Smoke Test

- [ ] **Step 1: Run app on simulator**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5
```

Then launch in Simulator via Xcode or `xcrun simctl launch`.

- [ ] **Step 2: Verify migration**
  - Fresh install: Profile tab shows "Track Your STI Tests" empty state card.
  - If upgrading from a build with `lastSTITestDate` set in UserDefaults (manually set via debug menu or by modifying UserDefaults in prior run): one test record should appear with Negative result.

- [ ] **Step 3: Verify add flow**
  - Tap "Log First Test" → `STITestFormView` opens.
  - Select a date, choose "Negative", add notes, tap Save.
  - Card in Profile shows last test date, status color, next test due.

- [ ] **Step 4: Verify history view**
  - Add 2–3 more tests with different result types.
  - Tap the card → `STIHistoryView` opens with vertical timeline showing all tests.
  - Dots are correctly colored (green for Negative, red for Positive, gray for Pending).

- [ ] **Step 5: Verify reminders**
  - In `STIHistoryView`, toggle "Test Reminders" on.
  - Select "Every 30 days" interval.
  - Go to device Settings → Notifications → verify Fuckify notification exists.

- [ ] **Step 6: Verify edit and delete**
  - Tap a test row → `STITestDetailView` opens.
  - Tap Edit → change result type, save. Verify timeline updates.
  - Swipe-to-delete a test → confirm alert → test removed.

- [ ] **Step 7: Commit if any fixes were needed**

```bash
git add -A && git commit -m "fix(sti): smoke test fixes"
```

---

## Self-Review Notes

- All types used in later tasks (`STIManager`, `SQLSTITest`, `SQLSTITestResultType`, `STIHistoryView`, `STITestFormView`) are defined in earlier tasks — no forward references.
- `rescheduleReminderIfEnabled()` is defined as a private method on `STIManager` in Task 5 and exposed as an extension in Task 10 (`STIHistoryView`). The extension in Task 10 re-declares it as `internal` to avoid the private restriction — this works because it's in a separate file. However, the simpler fix is to make it `internal` (not `private`) in STIManager directly. **Update Task 5:** change `private func rescheduleReminderIfEnabled()` to `func rescheduleReminderIfEnabled()` and remove the extension re-declaration in Task 10.
- `SQLSTITestResultType.displayColor` references `Color` but the import is `Foundation` + `SQLiteData`. **Add `import SwiftUI`** to `SQLSTITest.swift` in Task 1.
- `@Bindable var bindableProfile = profile` in `STIHistoryView` requires the `@Observable` macro — this is correct since `UserProfile` uses `@Observable`. The `@Bindable` property wrapper works in views when the object is `@Observable`.
