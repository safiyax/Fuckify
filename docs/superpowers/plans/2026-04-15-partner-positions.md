# Partner Positions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional per-partner and per-user position tracking (Top/Bottom/Switch + user-customizable) to encounters.

**Architecture:** New `positionType` catalog table mirrors `activityType`. Two `ALTER TABLE ADD COLUMN` migrations add nullable `positionTypeId` to both `encounter` and `encounterPartner`. `EncounterService.create/update` signatures extended with position parameters. `EncounterFormView` gains two new sections; settings gains a Positions screen parallel to Activities and Protection Methods.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLiteData (GRDB), Dependencies (pointfree-co/swift-dependencies)

---

## File Map

**Create:**
- `Fuckify/Database/Models/SQLPositionType.swift` — `SQLPositionType` struct with predefined UUIDs
- `Fuckify/Database/Services/PositionTypeService.swift` — catalog CRUD service
- `Fuckify/Database/Migrations/AddPositionTypes.swift` — Migration 11
- `Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift` — partner positions section component
- `Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift` — settings list view
- `Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift` — add/edit form

**Modify:**
- `Fuckify/Database/Models/SQLEncounterPartner.swift` — add `positionTypeId: UUID?`
- `Fuckify/Database/Models/SQLEncounter.swift` — add `positionTypeId: UUID?` to `SQLEncounter`
- `Fuckify/Database/Services/EncounterService.swift` — extend `create`/`update` signatures; extend `fetchAllWithRelationships` and `EncounterWithRelationships`
- `Fuckify/Database/AppDatabase.swift` — register Migration 11
- `Fuckify/Features/Encounter/ViewModels/EncountersManager.swift` — add `positionTypes: [SQLPositionType]`
- `Fuckify/Features/Encounter/Views/EncounterFormView.swift` — add My Position + Partner Positions sections
- `Fuckify/Features/Encounter/Views/EncounterDetailView.swift` — display positions
- Settings navigation — add Positions entry alongside Activities and Protection Methods

---

## Task 1: SQLPositionType Model

**Files:**
- Create: `Fuckify/Database/Models/SQLPositionType.swift`

- [ ] **Step 1: Create the model file**

```swift
//
//  SQLPositionType.swift
//  Fuckify
//

import Foundation
import SQLiteData

// MARK: - Position Type (Catalog — mirrors activityType pattern)

@Table("positionType")
struct SQLPositionType: Identifiable, Equatable {
    let id: UUID
    var name: String
    var icon: String        // SF Symbol name
    var isBuiltIn: Bool
    var isEnabled: Bool
    var sortOrder: Int
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

// MARK: - Predefined UUIDs

extension SQLPositionType {
    nonisolated static let topId     = UUID(uuidString: "00000000-0000-0000-0000-000000000401")!
    nonisolated static let bottomId  = UUID(uuidString: "00000000-0000-0000-0000-000000000402")!
    nonisolated static let switchId  = UUID(uuidString: "00000000-0000-0000-0000-000000000403")!

    nonisolated static var builtIns: [SQLPositionType] {
        [
            SQLPositionType(id: topId,    name: "Top",    icon: "arrow.up.circle.fill",            isBuiltIn: true, isEnabled: true, sortOrder: 0, dateAdded: Date()),
            SQLPositionType(id: bottomId, name: "Bottom", icon: "arrow.down.circle.fill",          isBuiltIn: true, isEnabled: true, sortOrder: 1, dateAdded: Date()),
            SQLPositionType(id: switchId, name: "Switch", icon: "arrow.up.arrow.down.circle.fill", isBuiltIn: true, isEnabled: true, sortOrder: 2, dateAdded: Date()),
        ]
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Database/Models/SQLPositionType.swift
git commit -m "feat(positions): add SQLPositionType model with predefined UUIDs"
```

---

## Task 2: Update SQLEncounterPartner and SQLEncounter models

**Files:**
- Modify: `Fuckify/Database/Models/SQLEncounterPartner.swift`
- Modify: `Fuckify/Database/Models/SQLEncounter.swift`

- [ ] **Step 1: Add `positionTypeId` to `SQLEncounterPartner`**

Replace the entire contents of `Fuckify/Database/Models/SQLEncounterPartner.swift` with:

```swift
//
//  SQLEncounterPartner.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2026-01-05.
//

import Foundation
import SQLiteData

/// Junction table representing Encounter-Partner many-to-many relationship
@Table("encounterPartner")
struct SQLEncounterPartner: Identifiable {
    let id: UUID
    var encounterId: UUID
    var partnerId: UUID
    var positionTypeId: UUID?   // Optional position for this partner in this encounter
}
```

- [ ] **Step 2: Add `positionTypeId` to `SQLEncounter`**

In `Fuckify/Database/Models/SQLEncounter.swift`, find the `SQLEncounter` struct and add `positionTypeId` after `reachedOrgasm`:

```swift
    // Experience
    var rating: Int = 5 // 1-5 stars
    var reachedOrgasm: Bool = false
    var positionTypeId: UUID? = nil   // User's own position for this encounter
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Database/Models/SQLEncounterPartner.swift Fuckify/Database/Models/SQLEncounter.swift
git commit -m "feat(positions): add positionTypeId to SQLEncounter and SQLEncounterPartner"
```

---

## Task 3: Database Migration

**Files:**
- Create: `Fuckify/Database/Migrations/AddPositionTypes.swift`
- Modify: `Fuckify/Database/AppDatabase.swift`

- [ ] **Step 1: Create the migration file**

```swift
//
//  AddPositionTypes.swift
//  Fuckify
//
//  Migration 11: Add positionType catalog table and nullable positionTypeId columns
//

import Foundation
import SQLiteData

struct AddPositionTypes {
    nonisolated static func migrate(_ db: Database) throws {
        // 1. Create positionType catalog table
        try db.execute(sql: """
            CREATE TABLE "positionType"(
                "id" TEXT NOT NULL PRIMARY KEY,
                "name" TEXT NOT NULL,
                "icon" TEXT NOT NULL,
                "isBuiltIn" INTEGER NOT NULL,
                "isEnabled" INTEGER NOT NULL,
                "sortOrder" INTEGER NOT NULL,
                "dateAdded" TEXT NOT NULL
            ) STRICT
        """)

        // 2. Seed built-in position types
        // Pass Date() directly — NOT ISO8601 string — so GRDB encodes correctly
        let topId    = "00000000-0000-0000-0000-000000000401"
        let bottomId = "00000000-0000-0000-0000-000000000402"
        let switchId = "00000000-0000-0000-0000-000000000403"
        let now = Date()

        let insertSQL = """
            INSERT INTO "positionType" ("id","name","icon","isBuiltIn","isEnabled","sortOrder","dateAdded")
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """
        try db.execute(sql: insertSQL, arguments: [topId,    "Top",    "arrow.up.circle.fill",            1, 1, 0, now])
        try db.execute(sql: insertSQL, arguments: [bottomId, "Bottom", "arrow.down.circle.fill",          1, 1, 1, now])
        try db.execute(sql: insertSQL, arguments: [switchId, "Switch", "arrow.up.arrow.down.circle.fill", 1, 1, 2, now])

        // 3. Add nullable positionTypeId to encounter (user's own position)
        try db.execute(sql: """
            ALTER TABLE "encounter" ADD COLUMN "positionTypeId" TEXT
        """)

        // 4. Add nullable positionTypeId to encounterPartner (per-partner position)
        try db.execute(sql: """
            ALTER TABLE "encounterPartner" ADD COLUMN "positionTypeId" TEXT
        """)
    }
}
```

- [ ] **Step 2: Register migration in AppDatabase.swift**

In `Fuckify/Database/AppDatabase.swift`, after the `"Normalize STI test IDs"` registration, add:

```swift
    migrator.registerMigration("Add position types") { db in
        try AddPositionTypes.migrate(db)
    }
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Database/Migrations/AddPositionTypes.swift Fuckify/Database/AppDatabase.swift
git commit -m "feat(positions): add migration 11 — positionType table and nullable FK columns"
```

---

## Task 4: PositionTypeService

**Files:**
- Create: `Fuckify/Database/Services/PositionTypeService.swift`

- [ ] **Step 1: Create the service**

```swift
//
//  PositionTypeService.swift
//  Fuckify
//
//  Service for managing position type catalog (mirrors STIResultTypeService pattern)
//

import Foundation
import Dependencies
import SQLiteData
import GRDB

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PositionTypeService")

enum PositionTypeError: LocalizedError {
    case cannotDeleteBuiltIn
    case hasAssociatedEncounters

    var errorDescription: String? {
        switch self {
        case .cannotDeleteBuiltIn:
            return "Built-in position types cannot be deleted. You can disable them instead."
        case .hasAssociatedEncounters:
            return "This position type is used in existing encounters and cannot be deleted."
        }
    }
}

struct PositionTypeService {
    @Dependency(\.defaultDatabase) var database

    nonisolated init() {}

    // MARK: - Read

    func fetchAll() throws -> [SQLPositionType] {
        try database.read { db in
            try SQLPositionType
                .where { $0.isEnabled.eq(true) }
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    func fetchAllIncludingDisabled() throws -> [SQLPositionType] {
        try database.read { db in
            try SQLPositionType
                .order { $0.sortOrder.asc() }
                .fetchAll(db)
        }
    }

    // MARK: - Create

    func create(name: String, icon: String) throws -> UUID {
        try database.write { db in
            let maxSortOrder = try Int.fetchOne(
                db,
                sql: "SELECT COALESCE(MAX(sortOrder), 0) FROM positionType"
            ) ?? 0
            let entity = SQLPositionType(
                id: UUID(),
                name: name,
                icon: icon,
                isBuiltIn: false,
                isEnabled: true,
                sortOrder: maxSortOrder + 1,
                dateAdded: Date()
            )
            try SQLPositionType.insert { entity }.execute(db)
            logger.info("Created position type: \(entity.id)")
            return entity.id
        }
    }

    // MARK: - Update

    func update(_ positionType: SQLPositionType) throws {
        try database.write { db in
            try SQLPositionType.update(positionType).execute(db)
            logger.info("Updated position type: \(positionType.id)")
        }
    }

    // MARK: - Delete

    func delete(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLPositionType.find(id).fetchOne(db) else { return }

            if entity.isBuiltIn {
                throw PositionTypeError.cannotDeleteBuiltIn
            }

            // Check encounter.positionTypeId references
            let encounterCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM encounter WHERE positionTypeId = ?",
                arguments: [id]
            ) ?? 0

            // Check encounterPartner.positionTypeId references
            let partnerCount = try Int.fetchOne(
                db,
                sql: "SELECT COUNT(*) FROM encounterPartner WHERE positionTypeId = ?",
                arguments: [id]
            ) ?? 0

            if encounterCount + partnerCount > 0 {
                throw PositionTypeError.hasAssociatedEncounters
            }

            try SQLPositionType
                .where { $0.id.eq(id) }
                .delete()
                .execute(db)
            logger.info("Deleted position type: \(id)")
        }
    }

    // MARK: - Toggle

    func toggle(_ id: UUID) throws {
        try database.write { db in
            guard let entity = try SQLPositionType.find(id).fetchOne(db) else { return }
            var updated = entity
            updated.isEnabled.toggle()

            if updated.isBuiltIn {
                // Use raw SQL for built-ins — matches CustomizationService pattern
                try db.execute(
                    sql: "UPDATE positionType SET isEnabled = ?, sortOrder = ? WHERE id = ?",
                    arguments: [updated.isEnabled, updated.sortOrder, updated.id]
                )
            } else {
                try SQLPositionType.update(updated).execute(db)
            }
            logger.info("Toggled position type \(id): isEnabled=\(updated.isEnabled)")
        }
    }

    // MARK: - Seed

    func seedDefaults() throws {
        try database.write { db in
            for positionType in SQLPositionType.builtIns {
                let existing = try SQLPositionType.find(positionType.id).fetchOne(db)
                if existing == nil {
                    try SQLPositionType.insert { positionType }.execute(db)
                }
            }
        }
    }
}

// MARK: - Dependency Key

extension PositionTypeService: DependencyKey {
    nonisolated static var liveValue: PositionTypeService { PositionTypeService() }
}

extension DependencyValues {
    var positionTypeService: PositionTypeService {
        get { self[PositionTypeService.self] }
        set { self[PositionTypeService.self] = newValue }
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Database/Services/PositionTypeService.swift
git commit -m "feat(positions): add PositionTypeService"
```

---

## Task 5: Update EncounterService and EncounterWithRelationships

**Files:**
- Modify: `Fuckify/Database/Services/EncounterService.swift`

This is the largest change. The `EncounterWithRelationships` struct gains position data. `create` and `update` gain position parameters. `fetchAllWithRelationships` batch-loads partner positions.

- [ ] **Step 1: Update `EncounterWithRelationships`**

Find the `EncounterWithRelationships` struct (lines 17-35) and replace it with:

```swift
struct EncounterWithRelationships: Identifiable {
    let encounter: SQLEncounter
    let partners: [SQLPartner]
    let activityEntities: [SQLActivityTypeEntity]
    let protectionEntities: [SQLProtectionMethodEntity]
    /// Maps partnerId → SQLPositionType (nil if no position set for that partner)
    let partnerPositions: [UUID: SQLPositionType]
    /// The user's own position for this encounter
    let myPosition: SQLPositionType?

    var id: UUID { encounter.id }

    init(
        encounter: SQLEncounter,
        partners: [SQLPartner],
        activityEntities: [SQLActivityTypeEntity] = [],
        protectionEntities: [SQLProtectionMethodEntity] = [],
        partnerPositions: [UUID: SQLPositionType] = [:],
        myPosition: SQLPositionType? = nil
    ) {
        self.encounter = encounter
        self.partners = partners
        self.activityEntities = activityEntities
        self.protectionEntities = protectionEntities
        self.partnerPositions = partnerPositions
        self.myPosition = myPosition
    }
}
```

- [ ] **Step 2: Update `create()` signature and implementation**

Replace the `create()` function signature:

```swift
func create(
    _ encounterDraft: SQLEncounter.Draft,
    partnerIDs: [UUID],
    partnerPositionTypeIDs: [UUID: UUID?] = [:],
    myPositionTypeId: UUID? = nil,
    activityTypeIDs: [UUID],
    protectionMethodIDs: [UUID]
) throws -> UUID {
    try database.write { db in
        let encounterID = encounterDraft.id ?? UUID()
        let encounter = SQLEncounter(
            id: encounterID,
            date: encounterDraft.date,
            duration: encounterDraft.duration,
            location: encounterDraft.location,
            notes: encounterDraft.notes,
            rating: encounterDraft.rating,
            reachedOrgasm: encounterDraft.reachedOrgasm,
            positionTypeId: myPositionTypeId,
            dateAdded: encounterDraft.dateAdded
        )

        try SQLEncounter.insert { encounter }.execute(db)

        // Link partners with positions
        for partnerID in partnerIDs {
            let positionId = partnerPositionTypeIDs[partnerID] ?? nil
            let junction = SQLEncounterPartner(
                id: UUID(),
                encounterId: encounterID,
                partnerId: partnerID,
                positionTypeId: positionId
            )
            try SQLEncounterPartner.insert { junction }.execute(db)
        }

        // Link activities
        try EncounterActivity.insert {
            activityTypeIDs.map { activityTypeID in
                EncounterActivity(id: UUID(), encounterId: encounterID, activityTypeId: activityTypeID)
            }
        }.execute(db)

        // Link protection methods
        try EncounterProtectionMethod.insert {
            protectionMethodIDs.map { methodID in
                EncounterProtectionMethod(id: UUID(), encounterId: encounterID, protectionMethodId: methodID)
            }
        }.execute(db)

        // Update lastEncounterDate for all partners
        if let encounterDate = encounter.date {
            for partnerID in partnerIDs {
                guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else { continue }
                if partner.lastEncounterDate == nil || partner.lastEncounterDate! < encounterDate {
                    partner.lastEncounterDate = encounterDate
                    try SQLPartner.update(partner).execute(db)
                }
            }
        }

        logger.info("Created encounter: \(encounterID) with \(partnerIDs.count) partners")
        return encounterID
    }
}
```

- [ ] **Step 3: Update `update()` signature and implementation**

Replace the `update()` function:

```swift
func update(
    _ encounter: SQLEncounter,
    partnerIDs: [UUID]? = nil,
    partnerPositionTypeIDs: [UUID: UUID?]? = nil,
    myPositionTypeId: UUID?? = nil,
    activityTypeIDs: [UUID]? = nil,
    protectionMethodIDs: [UUID]? = nil
) throws {
    try database.write { db in
        let oldPartnerIDs = try SQLEncounterPartner
            .where { $0.encounterId.eq(encounter.id) }
            .fetchAll(db)
            .map { $0.partnerId }

        // Apply myPositionTypeId if provided (double-optional: nil = don't touch)
        var updatedEncounter = encounter
        if let newMyPosition = myPositionTypeId {
            updatedEncounter.positionTypeId = newMyPosition
        }
        try SQLEncounter.update(updatedEncounter).execute(db)

        if let newPartnerIDs = partnerIDs {
            // Delete existing junction rows
            try SQLEncounterPartner
                .where { $0.encounterId.eq(encounter.id) }
                .delete()
                .execute(db)

            // Re-insert with positions
            let positions = partnerPositionTypeIDs ?? [:]
            for partnerID in newPartnerIDs {
                let positionId = positions[partnerID] ?? nil
                let junction = SQLEncounterPartner(
                    id: UUID(),
                    encounterId: encounter.id,
                    partnerId: partnerID,
                    positionTypeId: positionId
                )
                try SQLEncounterPartner.insert { junction }.execute(db)
            }

            let allAffectedPartnerIDs = Set(oldPartnerIDs + newPartnerIDs)
            for partnerID in allAffectedPartnerIDs {
                try recalculateLastEncounterDate(for: partnerID, db: db)
            }
        } else if let encounterDate = updatedEncounter.date {
            for partnerID in oldPartnerIDs {
                guard var partner = try SQLPartner.find(partnerID).fetchOne(db) else { continue }
                if partner.lastEncounterDate == nil || partner.lastEncounterDate! < encounterDate {
                    partner.lastEncounterDate = encounterDate
                    try SQLPartner.update(partner).execute(db)
                }
            }
        }

        if let newActivityTypeIDs = activityTypeIDs {
            try EncounterActivity.where { $0.encounterId.eq(encounter.id) }.delete().execute(db)
            try EncounterActivity.insert {
                newActivityTypeIDs.map { EncounterActivity(id: UUID(), encounterId: encounter.id, activityTypeId: $0) }
            }.execute(db)
        }

        if let newProtectionMethodIDs = protectionMethodIDs {
            try EncounterProtectionMethod.where { $0.encounterId.eq(encounter.id) }.delete().execute(db)
            try EncounterProtectionMethod.insert {
                newProtectionMethodIDs.map { EncounterProtectionMethod(id: UUID(), encounterId: encounter.id, protectionMethodId: $0) }
            }.execute(db)
        }
    }
}
```

- [ ] **Step 4: Update `fetchAllWithRelationships()` to load position data**

In `fetchAllWithRelationships()`, after loading `protectionEntitiesByEncounter`, add position loading before the final `return` statement:

```swift
// 5. Batch load ALL position types referenced by encounterPartner rows
let allPositionTypeIDs = Set(partnerJunctions.compactMap { $0.positionTypeId })
var positionTypesByID: [UUID: SQLPositionType] = [:]
if !allPositionTypeIDs.isEmpty {
    let positionTypes = try SQLPositionType
        .where { allPositionTypeIDs.contains($0.id) }
        .fetchAll(db)
    positionTypesByID = Dictionary(uniqueKeysWithValues: positionTypes.map { ($0.id, $0) })
}

// Also load position types for encounter.positionTypeId (my positions)
let myPositionTypeIDs = Set(encounters.compactMap { $0.positionTypeId })
var myPositionTypesByID: [UUID: SQLPositionType] = [:]
if !myPositionTypeIDs.isEmpty {
    let myPositionTypes = try SQLPositionType
        .where { myPositionTypeIDs.contains($0.id) }
        .fetchAll(db)
    // Merge into same dict (same table, UUIDs are unique)
    for pt in myPositionTypes { myPositionTypesByID[pt.id] = pt }
}

// Build partnerPositions per encounter: [encounterId: [partnerId: SQLPositionType]]
var partnerPositionsByEncounter: [UUID: [UUID: SQLPositionType]] = [:]
for junction in partnerJunctions {
    guard let positionId = junction.positionTypeId,
          let position = positionTypesByID[positionId] else { continue }
    partnerPositionsByEncounter[junction.encounterId, default: [:]][junction.partnerId] = position
}
```

Then update the final `return` in `fetchAllWithRelationships`:

```swift
return encounters.map { encounter in
    EncounterWithRelationships(
        encounter: encounter,
        partners: partnersByEncounter[encounter.id] ?? [],
        activityEntities: activityEntitiesByEncounter[encounter.id] ?? [],
        protectionEntities: protectionEntitiesByEncounter[encounter.id] ?? [],
        partnerPositions: partnerPositionsByEncounter[encounter.id] ?? [:],
        myPosition: encounter.positionTypeId.flatMap { myPositionTypesByID[$0] }
    )
}
```

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep "error:" | head -20
```

Expected: Zero errors. Fix any that appear — they will be call sites that pass the old `create()`/`update()` signatures (the new parameters have defaults so existing calls remain valid).

- [ ] **Step 6: Commit**

```bash
git add Fuckify/Database/Services/EncounterService.swift
git commit -m "feat(positions): extend EncounterService with position type support"
```

---

## Task 6: Update EncountersManager

**Files:**
- Modify: `Fuckify/Features/Encounter/ViewModels/EncountersManager.swift`

- [ ] **Step 1: Add `positionTypes` state and update `addEncounter`/`updateEncounter`**

Add `positionTypes: [SQLPositionType] = []` to the Published State section:

```swift
var positionTypes: [SQLPositionType] = []
```

Update `fetchEncounters()` to also load position types. After setting `encountersWithRelationships`, add:

```swift
do {
    positionTypes = try PositionTypeService().fetchAll()
} catch {
    logger.error("Failed to fetch position types: \(error.localizedDescription)")
}
```

Update `addEncounter()` signature:

```swift
func addEncounter(
    _ encounterDraft: SQLEncounter.Draft,
    partnerIDs: [UUID],
    partnerPositionTypeIDs: [UUID: UUID?] = [:],
    myPositionTypeId: UUID? = nil,
    activityTypeIDs: [UUID],
    protectionMethodIDs: [UUID]
) async {
    do {
        let encounterID = try encounterService.create(
            encounterDraft,
            partnerIDs: partnerIDs,
            partnerPositionTypeIDs: partnerPositionTypeIDs,
            myPositionTypeId: myPositionTypeId,
            activityTypeIDs: activityTypeIDs,
            protectionMethodIDs: protectionMethodIDs
        )
        logger.info("Created encounter: \(encounterID)")
        await fetchEncounters()
    } catch {
        logger.error("Failed to create encounter: \(error.localizedDescription)")
        errorMessage = "Unable to create encounter. Please try again."
    }
}
```

Update `updateEncounter()` signature:

```swift
func updateEncounter(
    _ encounter: SQLEncounter,
    partnerIDs: [UUID]? = nil,
    partnerPositionTypeIDs: [UUID: UUID?]? = nil,
    myPositionTypeId: UUID?? = nil,
    activityTypeIDs: [UUID]? = nil,
    protectionMethodIDs: [UUID]? = nil
) async {
    do {
        try encounterService.update(
            encounter,
            partnerIDs: partnerIDs,
            partnerPositionTypeIDs: partnerPositionTypeIDs,
            myPositionTypeId: myPositionTypeId,
            activityTypeIDs: activityTypeIDs,
            protectionMethodIDs: protectionMethodIDs
        )
        logger.info("Updated encounter: \(encounter.id)")
        await fetchEncounters()
    } catch {
        logger.error("Failed to update encounter: \(error.localizedDescription)")
        errorMessage = "Unable to update encounter. Please try again."
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Encounter/ViewModels/EncountersManager.swift
git commit -m "feat(positions): add positionTypes to EncountersManager, extend add/update signatures"
```

---

## Task 7: PositionsSelectionSection Component

**Files:**
- Create: `Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift`

This component renders the "My Position" picker and the "Partner Positions" section in `EncounterFormView`.

- [ ] **Step 1: Create the component**

```swift
//
//  PositionsSelectionSection.swift
//  Fuckify
//
//  Position selection sections for encounter forms
//

import SwiftUI

// MARK: - My Position Section

struct MyPositionSection: View {
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?

    var body: some View {
        Section("My Position") {
            if availablePositions.isEmpty {
                Text("No position types available")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else if availablePositions.count <= 3 {
                Picker("Position", selection: $selectedPositionId) {
                    Text("None").tag(UUID?.none)
                    ForEach(availablePositions) { position in
                        Label(position.name, systemImage: position.icon)
                            .tag(Optional(position.id))
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Picker("Position", selection: $selectedPositionId) {
                    Text("None").tag(UUID?.none)
                    ForEach(availablePositions) { position in
                        Label(position.name, systemImage: position.icon)
                            .tag(Optional(position.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

// MARK: - Partner Positions Section

struct PartnerPositionsSection: View {
    let partners: [SQLPartner]
    let availablePositions: [SQLPositionType]
    @Binding var partnerPositionTypeIDs: [UUID: UUID?]

    var body: some View {
        if !partners.isEmpty && !availablePositions.isEmpty {
            Section("Partner Positions") {
                ForEach(partners) { partner in
                    PartnerPositionRow(
                        partner: partner,
                        availablePositions: availablePositions,
                        selectedPositionId: Binding(
                            get: { partnerPositionTypeIDs[partner.id] ?? nil },
                            set: { partnerPositionTypeIDs[partner.id] = $0 }
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Partner Position Row

private struct PartnerPositionRow: View {
    let partner: SQLPartner
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?

    var body: some View {
        HStack {
            // Partner avatar
            ZStack {
                Circle()
                    .fill(Color(partner.avatarColor))
                    .frame(width: 32, height: 32)
                Text(partner.initials)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            Text(partner.name)
                .font(.body)

            Spacer()

            if availablePositions.count <= 3 {
                Picker("", selection: $selectedPositionId) {
                    Text("—").tag(UUID?.none)
                    ForEach(availablePositions) { position in
                        Text(position.name).tag(Optional(position.id))
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            } else {
                Picker("", selection: $selectedPositionId) {
                    Text("None").tag(UUID?.none)
                    ForEach(availablePositions) { position in
                        Label(position.name, systemImage: position.icon)
                            .tag(Optional(position.id))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}

#Preview {
    let positions = SQLPositionType.builtIns
    let partner = SQLPartner()

    return Form {
        MyPositionSection(
            availablePositions: positions,
            selectedPositionId: .constant(SQLPositionType.topId)
        )
        PartnerPositionsSection(
            partners: [partner],
            availablePositions: positions,
            partnerPositionTypeIDs: .constant([:])
        )
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift
git commit -m "feat(positions): add MyPositionSection and PartnerPositionsSection components"
```

---

## Task 8: Update EncounterFormView

**Files:**
- Modify: `Fuckify/Features/Encounter/Views/EncounterFormView.swift`

- [ ] **Step 1: Add state variables**

After `@State private var availableProtectionMethods: [SQLProtectionMethodEntity] = []`, add:

```swift
@State private var availablePositions: [SQLPositionType] = []
@State private var myPositionTypeId: UUID? = nil
@State private var partnerPositionTypeIDs: [UUID: UUID?] = [:]
```

- [ ] **Step 2: Load positions in `loadData()`**

In `loadData()`, after setting `availableProtectionMethods`, add:

```swift
do {
    availablePositions = try PositionTypeService().fetchAll()
} catch {
    availablePositions = []
}
```

- [ ] **Step 3: Clear partner positions when a partner is removed**

Update `togglePartner()`:

```swift
private func togglePartner(_ partnerID: UUID) {
    if selectedPartnerIDs.contains(partnerID) {
        selectedPartnerIDs.remove(partnerID)
        partnerPositionTypeIDs.removeValue(forKey: partnerID)
    } else {
        selectedPartnerIDs.insert(partnerID)
    }
}
```

- [ ] **Step 4: Load positions in `loadEncounter()`**

At the end of `loadEncounter()`, after loading `protectionEntities`, add:

```swift
// Load my position
myPositionTypeId = encounter.positionTypeId

// Load partner positions from junction table
do {
    let junctions = try encounterService.fetchEncounterPartnerJunctions(for: encounter.id)
    for junction in junctions {
        partnerPositionTypeIDs[junction.partnerId] = junction.positionTypeId
    }
} catch {
    // Non-fatal — positions just won't be pre-populated
}
```

Note: `fetchEncounterPartnerJunctions(for:)` needs to be added to `EncounterService` (see Step 5).

- [ ] **Step 5: Add `fetchEncounterPartnerJunctions` to EncounterService**

In `Fuckify/Database/Services/EncounterService.swift`, add this method in the Relationships section:

```swift
/// Fetch raw encounterPartner junction rows for a specific encounter (for loading positions)
func fetchEncounterPartnerJunctions(for encounterID: UUID) throws -> [SQLEncounterPartner] {
    try database.read { db in
        try SQLEncounterPartner
            .where { $0.encounterId.eq(encounterID) }
            .fetchAll(db)
    }
}
```

- [ ] **Step 6: Add position sections to the form body**

In `EncounterFormView.body`, after the `ProtectionMethodsSelectionSection(...)` call and before `RatingSection(...)`, add:

```swift
// My Position
MyPositionSection(
    availablePositions: availablePositions,
    selectedPositionId: $myPositionTypeId
)

// Partner Positions
PartnerPositionsSection(
    partners: selectedPartners,
    availablePositions: availablePositions,
    partnerPositionTypeIDs: $partnerPositionTypeIDs
)
```

- [ ] **Step 7: Pass positions to save calls in `saveEncounter()`**

Update the `encounterService.update(...)` call:

```swift
try encounterService.update(
    updated,
    partnerIDs: partnerIDs,
    partnerPositionTypeIDs: partnerPositionTypeIDs,
    myPositionTypeId: .some(myPositionTypeId),
    activityTypeIDs: activityTypeIDs,
    protectionMethodIDs: protectionMethodIDs
)
```

Update the `encounterService.create(...)` call:

```swift
_ = try encounterService.create(
    draft,
    partnerIDs: partnerIDs,
    partnerPositionTypeIDs: partnerPositionTypeIDs,
    myPositionTypeId: myPositionTypeId,
    activityTypeIDs: activityTypeIDs,
    protectionMethodIDs: protectionMethodIDs
)
```

- [ ] **Step 8: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 9: Commit**

```bash
git add Fuckify/Features/Encounter/Views/EncounterFormView.swift Fuckify/Database/Services/EncounterService.swift
git commit -m "feat(positions): add position selection to EncounterFormView"
```

---

## Task 9: Update EncounterDetailView

**Files:**
- Modify: `Fuckify/Features/Encounter/Views/EncounterDetailView.swift`

- [ ] **Step 1: Add position state**

After `@State private var protectionEntities: [SQLProtectionMethodEntity] = []`, add:

```swift
@State private var partnerPositions: [UUID: SQLPositionType] = [:]
@State private var myPosition: SQLPositionType? = nil
```

- [ ] **Step 2: Load positions on appear**

The detail view loads its relationships via `encounterService`. Add position loading alongside partners in the existing `.task` or `loadData()` call. After loading partners, add:

```swift
// Load positions
do {
    let junctions = try encounterService.fetchEncounterPartnerJunctions(for: currentEncounter.id)
    let allPositionIDs = Set(junctions.compactMap { $0.positionTypeId })
    if !allPositionIDs.isEmpty {
        let posTypes = try PositionTypeService().fetchAll()
        let posDict = Dictionary(uniqueKeysWithValues: posTypes.map { ($0.id, $0) })
        for junction in junctions {
            if let posId = junction.positionTypeId, let pos = posDict[posId] {
                partnerPositions[junction.partnerId] = pos
            }
        }
    }
    if let myPosId = currentEncounter.positionTypeId {
        myPosition = try PositionTypeService().fetchAll().first { $0.id == myPosId }
    }
} catch {
    // Non-fatal
}
```

- [ ] **Step 3: Display my position**

In the detail view body, after the "When" section, add a "Position" section if `myPosition` is non-nil:

```swift
if let myPos = myPosition {
    Section("My Position") {
        Label(myPos.name, systemImage: myPos.icon)
            .foregroundStyle(.primary)
    }
}
```

- [ ] **Step 4: Display partner positions inline**

In the Partners section, update the `ForEach(partners)` to show each partner's position badge below their chip:

```swift
ForEach(partners) { partner in
    VStack(alignment: .leading, spacing: 4) {
        Button {
            selectedPartner = partner
        } label: {
            EncounterDetailPartnerChip(partner: partner)
        }
        .buttonStyle(.plain)

        if let position = partnerPositions[partner.id] {
            Label(position.name, systemImage: position.icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
    }
}
```

- [ ] **Step 5: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Fuckify/Features/Encounter/Views/EncounterDetailView.swift
git commit -m "feat(positions): display positions in EncounterDetailView"
```

---

## Task 10: Positions Settings Screen

**Files:**
- Create: `Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift`
- Create: `Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift`

- [ ] **Step 1: Create PositionsSettingsView**

```swift
//
//  PositionsSettingsView.swift
//  Fuckify
//

import SwiftUI
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PositionsSettings")

struct PositionsSettingsView: View {
    @State private var positions: [SQLPositionType] = []
    @State private var positionToEdit: SQLPositionType?
    @State private var positionToDelete: SQLPositionType?
    @State private var showingAddPosition = false
    @State private var showingDeleteAlert = false
    @State private var deleteError: String?
    @State private var showingDeleteError = false

    private let service = PositionTypeService()
    private let accentColor = Color.orange

    var builtInPositions: [SQLPositionType] { positions.filter { $0.isBuiltIn } }
    var customPositions: [SQLPositionType] { positions.filter { !$0.isBuiltIn } }

    var body: some View {
        List {
            Section {
                Text("Manage positions for logging encounters. Built-in positions can be enabled/disabled. Custom positions can be edited or deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !builtInPositions.isEmpty {
                Section("Built-in Positions") {
                    ForEach(builtInPositions) { position in
                        PositionRow(position: position, onToggle: { toggle(position) })
                    }
                }
            }

            Section {
                ForEach(customPositions) { position in
                    PositionRow(position: position, onToggle: { toggle(position) })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                positionToDelete = position
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                positionToEdit = position
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
                Button {
                    showingAddPosition = true
                } label: {
                    Label("Add Custom Position", systemImage: "plus.circle.fill")
                        .foregroundStyle(.accentColor)
                }
            } header: {
                Text("Custom Positions")
            } footer: {
                if customPositions.isEmpty {
                    Text("Tap + to add your own custom positions")
                        .font(.caption)
                }
            }
        }
        .tint(accentColor)
        .navigationTitle("Positions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddPosition = true } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .onAppear { load() }
        .sheet(isPresented: $showingAddPosition) {
            PositionFormView(onSave: { load() }).tint(accentColor)
        }
        .sheet(item: $positionToEdit) { position in
            PositionFormView(position: position, onSave: { load() }).tint(accentColor)
        }
        .alert("Delete Position", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let p = positionToDelete { deletePosition(p) }
            }
        } message: {
            Text("Are you sure you want to delete this custom position?")
        }
        .alert("Cannot Delete", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "This position cannot be deleted.")
        }
    }

    private func load() {
        positions = (try? service.fetchAllIncludingDisabled()) ?? []
    }

    private func toggle(_ position: SQLPositionType) {
        try? service.toggle(position.id)
        load()
    }

    private func deletePosition(_ position: SQLPositionType) {
        do {
            try service.delete(position.id)
            load()
        } catch {
            deleteError = error.localizedDescription
            showingDeleteError = true
        }
    }
}

// MARK: - Position Row

struct PositionRow: View {
    let position: SQLPositionType
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: position.icon)
                .font(.title3)
                .foregroundStyle(position.isEnabled ? .orange : .gray)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(position.name)
                    .foregroundStyle(position.isEnabled ? .primary : .secondary)
                if position.isBuiltIn {
                    Text("Built-in")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { position.isEnabled }, set: { _ in onToggle() }))
                .labelsHidden()
                .accessibilityLabel("\(position.name) enabled")
        }
    }
}
```

- [ ] **Step 2: Create PositionFormView**

```swift
//
//  PositionFormView.swift
//  Fuckify
//

import SwiftUI
import Dependencies

struct PositionFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var errorMessage: String?

    let existingPosition: SQLPositionType?
    let onSave: () -> Void

    init(position: SQLPositionType? = nil, onSave: @escaping () -> Void) {
        self.existingPosition = position
        self.onSave = onSave
        _name = State(initialValue: position?.name ?? "")
        _selectedIcon = State(initialValue: position?.icon ?? "figure.stand")
    }

    var isEditing: Bool { existingPosition != nil }
    var isBuiltIn: Bool { existingPosition?.isBuiltIn ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Position Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if isBuiltIn { Text("Built-in positions cannot be renamed").font(.caption).foregroundStyle(.secondary) }
                }

                Section("Icon") {
                    Button {
                        if !isBuiltIn { showingIconPicker = true }
                    } label: {
                        HStack {
                            Image(systemName: selectedIcon)
                                .foregroundStyle(.orange)
                                .font(.title2)
                                .frame(width: 40, height: 40)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                            Text("Choose Icon")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isBuiltIn)
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.caption) }
                }
            }
            .navigationTitle(isEditing ? "Edit Position" : "Add Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Please enter a name"; return }

        let service = PositionTypeService()
        do {
            if let existing = existingPosition {
                if isBuiltIn { dismiss(); return }
                var updated = existing
                updated.name = trimmed
                updated.icon = selectedIcon
                try service.update(updated)
            } else {
                _ = try service.create(name: trimmed, icon: selectedIcon)
            }
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift \
        Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift
git commit -m "feat(positions): add PositionsSettingsView and PositionFormView"
```

---

## Task 11: Wire Positions into Settings Navigation

**Files:**
- Modify: whichever view contains the navigation links to `ActivitiesSettingsView` and `ProtectionMethodsSettingsView` in the settings hierarchy

- [ ] **Step 1: Find the settings customization navigation file**

```bash
grep -rn "ActivitiesSettingsView\|ProtectionMethodsSettingsView" /Users/zee/ws/spicy/Fuckify/Fuckify --include="*.swift" | grep -v "ActivitiesSettingsView.swift\|ProtectionMethodsSettingsView.swift"
```

- [ ] **Step 2: Add a NavigationLink to PositionsSettingsView**

In the file found above, add a `NavigationLink` for positions in the same section as activities and protection methods:

```swift
NavigationLink {
    PositionsSettingsView()
} label: {
    Label("Positions", systemImage: "arrow.up.arrow.down.circle.fill")
}
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(positions): wire Positions into settings navigation"
```

---

## Task 12: Manual Smoke Test

- [ ] **Step 1: Fresh install on simulator/device**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -3
```

Delete app from simulator and reinstall to ensure migration runs clean.

- [ ] **Step 2: Verify migration**

Migration 11 runs on launch. Check logs for no errors. The `positionType` table should exist with 3 rows.

- [ ] **Step 3: Verify encounter form**

- Create a new encounter with 2 partners
- Verify "My Position" section appears below Protection Methods
- Verify "Partner Positions" section appears with both partners listed
- Set your position to Top, Partner A to Bottom, Partner B unset
- Save — no crash

- [ ] **Step 4: Verify detail view**

- Open the saved encounter
- Verify "My Position: Top" appears
- Verify Partner A shows "Bottom" badge, Partner B shows nothing

- [ ] **Step 5: Verify edit round-trip**

- Edit the encounter
- Verify positions are pre-populated correctly (your Top, Partner A Bottom)
- Change your position to Switch, save
- Verify detail view reflects the change

- [ ] **Step 6: Verify settings**

- Settings → Customization → Positions
- Toggle "Bottom" off — verify it disappears from encounter form picker
- Add a custom position "Vers Top" with an icon
- Verify it appears in the encounter form picker

- [ ] **Step 7: Commit any fixes**

```bash
git add -A && git commit -m "fix(positions): smoke test fixes"
```

---

## Self-Review

**Spec coverage:**
- ✅ `positionType` catalog table with 3 built-ins (`0401`–`0403`)
- ✅ `ALTER TABLE encounter ADD COLUMN positionTypeId TEXT`
- ✅ `ALTER TABLE encounterPartner ADD COLUMN positionTypeId TEXT`
- ✅ `PositionTypeService` with all required methods
- ✅ `EncounterService.create/update` extended with position parameters (default values preserve backward compat)
- ✅ `EncountersManager.positionTypes` added
- ✅ `EncounterFormView` My Position + Partner Positions sections
- ✅ `EncounterDetailView` shows my position and partner positions
- ✅ Customization settings screen for positions
- ✅ Error handling: `cannotDeleteBuiltIn`, `hasAssociatedEncounters`, all-disabled empty state
- ✅ Partner removed → position cleared from `partnerPositionTypeIDs`

**Type consistency:**
- `SQLPositionType` used consistently throughout all tasks
- `partnerPositionTypeIDs: [UUID: UUID?]` used consistently in service, manager, and form
- `myPositionTypeId: UUID?` on create; `UUID??` on update — matches spec's double-optional pattern
- `fetchEncounterPartnerJunctions(for:)` defined in Task 8 Step 5, used in Tasks 8 and 9

**Placeholder scan:** No TBDs, no "implement later", no missing code blocks.
