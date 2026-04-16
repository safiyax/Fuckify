# Participant Accordion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flat Positions section in the encounter form with an accordion-style Participants section where each person (Me + partners) can expand to reveal a position picker and orgasm toggle.

**Architecture:** `SQLEncounterPartner` gains `hadOrgasm: Bool` via Migration 12. `EncounterService.create/update` gain `partnerOrgasms: [UUID: Bool]` parameter. `PositionsSelectionSection.swift` is replaced with `ParticipantsSection.swift` — a self-contained accordion component. `RatingSection` loses the orgasm toggle. `EncounterDetailView` shows orgasm alongside position per participant.

**Tech Stack:** Swift 5.9+, SwiftUI, SQLiteData (GRDB), Dependencies

---

## File Map

**Modify:**
- `Fuckify/Database/Models/SQLEncounterPartner.swift` — add `hadOrgasm: Bool`
- `Fuckify/Database/Migrations/AddPositionTypes.swift` → create new `Fuckify/Database/Migrations/AddParticipantOrgasm.swift` (Migration 12)
- `Fuckify/Database/AppDatabase.swift` — register Migration 12
- `Fuckify/Database/Services/EncounterService.swift` — add `partnerOrgasms` param to `create`/`update`; update junction insert
- `Fuckify/Features/Encounter/ViewModels/EncountersManager.swift` — update `addEncounter`/`updateEncounter` signatures
- `Fuckify/Features/Encounter/Components/RatingSection.swift` — remove `reachedOrgasm` toggle
- `Fuckify/Features/Encounter/Views/EncounterFormView.swift` — swap `PositionsSection` for `ParticipantsSection`; add `partnerOrgasms` state; load orgasm from junctions; save orgasm
- `Fuckify/Features/Encounter/Views/EncounterDetailView.swift` — show orgasm in participant summary

**Replace:**
- `Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift` → full rewrite as `ParticipantsSection`

---

## Task 1: Add `hadOrgasm` to SQLEncounterPartner

**Files:**
- Modify: `Fuckify/Database/Models/SQLEncounterPartner.swift`

- [ ] **Step 1: Add the field**

Replace the entire file contents with:

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
    var hadOrgasm: Bool         // Whether this partner had an orgasm
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep "error:" | head -20
```

Expected: Errors in `EncounterService.swift` where `SQLEncounterPartner` is constructed without `hadOrgasm` — these are fixed in Task 3. No other errors.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Database/Models/SQLEncounterPartner.swift
git commit -m "feat(participants): add hadOrgasm to SQLEncounterPartner"
```

---

## Task 2: Migration 12

**Files:**
- Create: `Fuckify/Database/Migrations/AddParticipantOrgasm.swift`
- Modify: `Fuckify/Database/AppDatabase.swift`

- [ ] **Step 1: Create the migration**

```swift
//
//  AddParticipantOrgasm.swift
//  Fuckify
//
//  Migration 12: Add hadOrgasm column to encounterPartner table
//

import Foundation
import SQLiteData

struct AddParticipantOrgasm {
    nonisolated static func migrate(_ db: Database) throws {
        // Add hadOrgasm column with default 0 (false) so existing rows are unaffected
        try db.execute(sql: """
            ALTER TABLE "encounterPartner" ADD COLUMN "hadOrgasm" INTEGER NOT NULL DEFAULT 0
        """)
    }
}
```

- [ ] **Step 2: Register in AppDatabase.swift**

After the `"Add position types"` registration, add:

```swift
    migrator.registerMigration("Add participant orgasm") { db in
        try AddParticipantOrgasm.migrate(db)
    }
```

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep "error:" | head -10
```

Expected: Same errors as Task 1 (EncounterService constructor mismatches). No new errors.

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Database/Migrations/AddParticipantOrgasm.swift Fuckify/Database/AppDatabase.swift
git commit -m "feat(participants): migration 12 — add hadOrgasm to encounterPartner"
```

---

## Task 3: Update EncounterService

**Files:**
- Modify: `Fuckify/Database/Services/EncounterService.swift`

Three changes: fix junction construction in `create`, fix junction construction in `update`, add `partnerOrgasms` parameter to both.

- [ ] **Step 1: Update `create()` signature and junction construction**

Change the `create` signature from:

```swift
func create(
    _ encounterDraft: SQLEncounter.Draft,
    partnerIDs: [UUID],
    partnerPositionTypeIDs: [UUID: UUID?] = [:],
    myPositionTypeId: UUID? = nil,
    activityTypeIDs: [UUID],
    protectionMethodIDs: [UUID]
) throws -> UUID {
```

To:

```swift
func create(
    _ encounterDraft: SQLEncounter.Draft,
    partnerIDs: [UUID],
    partnerPositionTypeIDs: [UUID: UUID?] = [:],
    partnerOrgasms: [UUID: Bool] = [:],
    myPositionTypeId: UUID? = nil,
    activityTypeIDs: [UUID],
    protectionMethodIDs: [UUID]
) throws -> UUID {
```

Inside `create`, replace the partner junction construction:

```swift
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
```

With:

```swift
            // Link partners with positions and orgasm status
            for partnerID in partnerIDs {
                let junction = SQLEncounterPartner(
                    id: UUID(),
                    encounterId: encounterID,
                    partnerId: partnerID,
                    positionTypeId: partnerPositionTypeIDs[partnerID] ?? nil,
                    hadOrgasm: partnerOrgasms[partnerID] ?? false
                )
                try SQLEncounterPartner.insert { junction }.execute(db)
            }
```

- [ ] **Step 2: Update `update()` signature and junction construction**

Change the `update` signature from:

```swift
func update(
    _ encounter: SQLEncounter,
    partnerIDs: [UUID]? = nil,
    partnerPositionTypeIDs: [UUID: UUID?]? = nil,
    myPositionTypeId: UUID?? = nil,
    activityTypeIDs: [UUID]? = nil,
    protectionMethodIDs: [UUID]? = nil
) throws {
```

To:

```swift
func update(
    _ encounter: SQLEncounter,
    partnerIDs: [UUID]? = nil,
    partnerPositionTypeIDs: [UUID: UUID?]? = nil,
    partnerOrgasms: [UUID: Bool]? = nil,
    myPositionTypeId: UUID?? = nil,
    activityTypeIDs: [UUID]? = nil,
    protectionMethodIDs: [UUID]? = nil
) throws {
```

Inside `update`, replace the partner re-insertion:

```swift
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
```

With:

```swift
                // Re-insert with positions and orgasm status
                let positions = partnerPositionTypeIDs ?? [:]
                let orgasms = partnerOrgasms ?? [:]
                for partnerID in newPartnerIDs {
                    let junction = SQLEncounterPartner(
                        id: UUID(),
                        encounterId: encounter.id,
                        partnerId: partnerID,
                        positionTypeId: positions[partnerID] ?? nil,
                        hadOrgasm: orgasms[partnerID] ?? false
                    )
                    try SQLEncounterPartner.insert { junction }.execute(db)
                }
```

- [ ] **Step 3: Build to verify — expect clean build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Database/Services/EncounterService.swift
git commit -m "feat(participants): add partnerOrgasms to EncounterService create/update"
```

---

## Task 4: Update EncountersManager

**Files:**
- Modify: `Fuckify/Features/Encounter/ViewModels/EncountersManager.swift`

- [ ] **Step 1: Update `addEncounter` signature**

Add `partnerOrgasms: [UUID: Bool] = [:]` after `partnerPositionTypeIDs`:

```swift
func addEncounter(
    _ encounterDraft: SQLEncounter.Draft,
    partnerIDs: [UUID],
    partnerPositionTypeIDs: [UUID: UUID?] = [:],
    partnerOrgasms: [UUID: Bool] = [:],
    myPositionTypeId: UUID? = nil,
    activityTypeIDs: [UUID],
    protectionMethodIDs: [UUID]
) async {
    do {
        let encounterID = try encounterService.create(
            encounterDraft,
            partnerIDs: partnerIDs,
            partnerPositionTypeIDs: partnerPositionTypeIDs,
            partnerOrgasms: partnerOrgasms,
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

- [ ] **Step 2: Update `updateEncounter` signature**

Add `partnerOrgasms: [UUID: Bool]? = nil` after `partnerPositionTypeIDs`:

```swift
func updateEncounter(
    _ encounter: SQLEncounter,
    partnerIDs: [UUID]? = nil,
    partnerPositionTypeIDs: [UUID: UUID?]? = nil,
    partnerOrgasms: [UUID: Bool]? = nil,
    myPositionTypeId: UUID?? = nil,
    activityTypeIDs: [UUID]? = nil,
    protectionMethodIDs: [UUID]? = nil
) async {
    do {
        try encounterService.update(
            encounter,
            partnerIDs: partnerIDs,
            partnerPositionTypeIDs: partnerPositionTypeIDs,
            partnerOrgasms: partnerOrgasms,
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

- [ ] **Step 3: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Features/Encounter/ViewModels/EncountersManager.swift
git commit -m "feat(participants): add partnerOrgasms to EncountersManager"
```

---

## Task 5: ParticipantsSection Component

**Files:**
- Modify: `Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift` (full rewrite)

This is the main UI task. The file is rewritten as a single `ParticipantsSection` with accordion rows.

- [ ] **Step 1: Replace the entire file**

```swift
//
//  PositionsSelectionSection.swift
//  Fuckify
//
//  Accordion-style participant section for encounter forms.
//  Each participant (Me + partners) can expand to reveal position and orgasm fields.
//

import SwiftUI

// MARK: - Participants Section

struct ParticipantsSection: View {
    let profile: UserProfile
    let partners: [SQLPartner]
    let availablePositions: [SQLPositionType]

    @Binding var myPositionTypeId: UUID?
    @Binding var myReachedOrgasm: Bool
    @Binding var partnerPositionTypeIDs: [UUID: UUID?]
    @Binding var partnerOrgasms: [UUID: Bool]

    // Sentinel UUID used to track expanded state for the "Me" row
    private let meID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        Section("Participants") {
            // Me row — always first
            ParticipantRow(
                id: meID,
                avatarColor: Color("AccentColor"),
                initials: profile.initials,
                name: profile.name.isEmpty ? "Me" : profile.name,
                availablePositions: availablePositions,
                selectedPositionId: $myPositionTypeId,
                hadOrgasm: $myReachedOrgasm,
                isExpanded: expandedIDs.contains(meID),
                onToggleExpand: { toggleExpand(meID) }
            )

            // Partner rows
            ForEach(partners) { partner in
                ParticipantRow(
                    id: partner.id,
                    avatarColor: partner.color,
                    initials: partner.initials,
                    name: partner.name,
                    availablePositions: availablePositions,
                    selectedPositionId: Binding(
                        get: { partnerPositionTypeIDs[partner.id] ?? nil },
                        set: { partnerPositionTypeIDs[partner.id] = $0 }
                    ),
                    hadOrgasm: Binding(
                        get: { partnerOrgasms[partner.id] ?? false },
                        set: { partnerOrgasms[partner.id] = $0 }
                    ),
                    isExpanded: expandedIDs.contains(partner.id),
                    onToggleExpand: { toggleExpand(partner.id) }
                )
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
}

// MARK: - Participant Row

private struct ParticipantRow: View {
    let id: UUID
    let avatarColor: Color
    let initials: String
    let name: String
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?
    @Binding var hadOrgasm: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible, tap to expand/collapse
            Button(action: onToggleExpand) {
                HStack {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(avatarColor)
                            .frame(width: 32, height: 32)
                        Text(initials)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }

                    Text(name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.vertical, 8)

                    // Position picker
                    if !availablePositions.isEmpty {
                        HStack {
                            Label("Position", systemImage: "figure.stand")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                            Spacer()
                            Picker("", selection: $selectedPositionId) {
                                Label("None", systemImage: "minus.circle")
                                    .tag(UUID?.none)
                                ForEach(availablePositions) { position in
                                    Label(position.name, systemImage: position.icon)
                                        .tag(Optional(position.id))
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.bottom, 8)
                    }

                    // Orgasm toggle
                    Toggle(isOn: $hadOrgasm) {
                        Label("Orgasm", systemImage: hadOrgasm ? "heart.fill" : "heart")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(.leading, 48)  // indent to align with name
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    let positions = SQLPositionType.builtIns
    let partner = SQLPartner(id: UUID(), name: "Alex")
    let profile = UserProfile()

    Form {
        ParticipantsSection(
            profile: profile,
            partners: [partner],
            availablePositions: positions,
            myPositionTypeId: .constant(SQLPositionType.topId),
            myReachedOrgasm: .constant(false),
            partnerPositionTypeIDs: .constant([:]),
            partnerOrgasms: .constant([:])
        )
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep "error:" | head -10
```

Expected: Errors in `EncounterFormView` where `PositionsSection` is used — fixed in Task 6. No other errors.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift
git commit -m "feat(participants): replace PositionsSection with accordion ParticipantsSection"
```

---

## Task 6: Update RatingSection

**Files:**
- Modify: `Fuckify/Features/Encounter/Components/RatingSection.swift`

Remove the `reachedOrgasm` binding and toggle — orgasm is now handled per-participant in `ParticipantsSection`.

- [ ] **Step 1: Replace RatingSection.swift**

```swift
//
//  RatingSection.swift
//  Fuckify
//
//  Reusable rating section for encounter forms
//

import SwiftUI

struct RatingSection: View {
    @Binding var rating: Int

    var body: some View {
        Section("Experience") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { rating = star }) {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .yellow : .gray)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                        .accessibilityAddTraits(rating == star ? [.isSelected] : [])
                        .accessibilityHint("Double tap to rate this encounter")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    Form {
        RatingSection(rating: .constant(4))
    }
}
```

- [ ] **Step 2: Build to verify**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep "error:" | head -10
```

Expected: Errors in `EncounterFormView` where `RatingSection` is called with `reachedOrgasm:` — fixed in Task 7.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Encounter/Components/RatingSection.swift
git commit -m "feat(participants): remove reachedOrgasm from RatingSection"
```

---

## Task 7: Update EncounterFormView

**Files:**
- Modify: `Fuckify/Features/Encounter/Views/EncounterFormView.swift`

Five changes: add `partnerOrgasms` state, update `togglePartner`, update `loadEncounter`, swap section in body, update `saveEncounter`.

- [ ] **Step 1: Add `partnerOrgasms` state variable**

After `@State private var partnerPositionTypeIDs: [UUID: UUID?] = [:]`, add:

```swift
@State private var partnerOrgasms: [UUID: Bool] = [:]
```

- [ ] **Step 2: Clear orgasm on partner deselect in `togglePartner()`**

Replace the existing `togglePartner` method:

```swift
private func togglePartner(_ partnerID: UUID) {
    if selectedPartnerIDs.contains(partnerID) {
        selectedPartnerIDs.remove(partnerID)
        partnerPositionTypeIDs.removeValue(forKey: partnerID)
        partnerOrgasms.removeValue(forKey: partnerID)
    } else {
        selectedPartnerIDs.insert(partnerID)
    }
}
```

- [ ] **Step 3: Load partner orgasms in `loadEncounter()`**

In `loadEncounter(_:)`, in the existing junction-loading block (after populating `partnerPositionTypeIDs`), add:

```swift
// Load partner orgasm status
for junction in junctions {
    partnerOrgasms[junction.partnerId] = junction.hadOrgasm
}
```

The full junction block should look like:

```swift
// Load partner positions and orgasms from junction rows
do {
    let junctions = try encounterService.fetchEncounterPartnerJunctions(for: encounter.id)
    for junction in junctions {
        partnerPositionTypeIDs[junction.partnerId] = junction.positionTypeId
        partnerOrgasms[junction.partnerId] = junction.hadOrgasm
    }
} catch {
    // Non-fatal — positions/orgasms just won't be pre-populated
}
```

- [ ] **Step 4: Replace `PositionsSection` with `ParticipantsSection` in body**

Replace:

```swift
                // Positions (Me + Partners combined)
                PositionsSection(
                    profile: profile,
                    partners: selectedPartners,
                    availablePositions: availablePositions,
                    myPositionTypeId: $myPositionTypeId,
                    partnerPositionTypeIDs: $partnerPositionTypeIDs
                )
```

With:

```swift
                // Participants (Me + Partners — position and orgasm per person)
                ParticipantsSection(
                    profile: profile,
                    partners: selectedPartners,
                    availablePositions: availablePositions,
                    myPositionTypeId: $myPositionTypeId,
                    myReachedOrgasm: $reachedOrgasm,
                    partnerPositionTypeIDs: $partnerPositionTypeIDs,
                    partnerOrgasms: $partnerOrgasms
                )
```

- [ ] **Step 5: Fix `RatingSection` call in body — remove `reachedOrgasm` argument**

Replace:

```swift
                // Experience
                RatingSection(rating: $rating, reachedOrgasm: $reachedOrgasm)
```

With:

```swift
                // Experience
                RatingSection(rating: $rating)
```

- [ ] **Step 6: Pass `partnerOrgasms` to `saveEncounter()`**

In `saveEncounter()`, in the editing branch, update the `encounterService.update(...)` call to add:

```swift
partnerOrgasms: partnerOrgasms,
```

After `partnerPositionTypeIDs: partnerPositionTypeIDs,`.

In the creating branch, update the `encounterService.create(...)` call to add:

```swift
partnerOrgasms: partnerOrgasms,
```

After `partnerPositionTypeIDs: partnerPositionTypeIDs,`.

- [ ] **Step 7: Build — expect clean build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add Fuckify/Features/Encounter/Views/EncounterFormView.swift
git commit -m "feat(participants): update EncounterFormView with ParticipantsSection and partnerOrgasms"
```

---

## Task 8: Update EncounterDetailView

**Files:**
- Modify: `Fuckify/Features/Encounter/Views/EncounterDetailView.swift`

Show orgasm status alongside position for each participant. Also fix the "My Position" section to show orgasm for the user.

- [ ] **Step 1: Add `partnerOrgasms` state**

After `@State private var partnerPositions: [UUID: SQLPositionType] = [:]`, add:

```swift
@State private var partnerOrgasms: [UUID: Bool] = [:]
```

- [ ] **Step 2: Load partner orgasms in the position-loading block**

In `loadEncounterData()`, inside the existing junction loop, add orgasm loading alongside the position lookup:

```swift
for junction in junctions {
    if let posId = junction.positionTypeId, let pos = posDict[posId] {
        partnerPositions[junction.partnerId] = pos
    }
    partnerOrgasms[junction.partnerId] = junction.hadOrgasm
}
```

Also add orgasm reset in `refreshEncounter()` where positions are reset:

```swift
partnerOrgasms = [:]
```

- [ ] **Step 3: Show orgasm in the Partners section**

In the `FlowLayout` partner chip section, update the `VStack` below each chip to show both position and orgasm:

```swift
ForEach(partners) { partner in
    VStack(alignment: .leading, spacing: 4) {
        Button {
            selectedPartner = partner
        } label: {
            EncounterDetailPartnerChip(partner: partner)
        }
        .buttonStyle(.plain)

        HStack(spacing: 8) {
            if let position = partnerPositions[partner.id] {
                Label(position.name, systemImage: position.icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if partnerOrgasms[partner.id] == true {
                Label("Orgasm", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 4)
    }
}
```

- [ ] **Step 4: Update "My Position" section to also show orgasm**

Replace the existing `Section("My Position")` block:

```swift
if let myPos = myPosition {
    Section("My Position") {
        Label(myPos.name, systemImage: myPos.icon)
    }
}
```

With:

```swift
if myPosition != nil || currentEncounter.reachedOrgasm {
    Section("Me") {
        if let myPos = myPosition {
            Label(myPos.name, systemImage: myPos.icon)
        }
        if currentEncounter.reachedOrgasm {
            Label("Orgasm", systemImage: "heart.fill")
        }
    }
}
```

- [ ] **Step 5: Build — expect clean build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Fuckify/Features/Encounter/Views/EncounterDetailView.swift
git commit -m "feat(participants): show orgasm per participant in EncounterDetailView"
```

---

## Task 9: Manual Smoke Test

- [ ] **Step 1: Delete app and reinstall on device/simulator to run clean migrations**

Migration 12 adds `hadOrgasm INTEGER NOT NULL DEFAULT 0` to `encounterPartner`. Existing rows get 0 (false) — no data loss.

- [ ] **Step 2: Verify accordion in encounter form**

- Create a new encounter with 2 partners
- "Participants" section shows Me + both partners, all collapsed with chevron
- Tap "Me" → expands to show Position picker + Orgasm toggle
- Set Me: Bottom, Orgasm: on
- Tap "Alex" → expands, set Position: Top, Orgasm: off
- Both collapse cleanly with chevron animation

- [ ] **Step 3: Verify RatingSection**

- "Experience" section shows only star rating — no orgasm toggle

- [ ] **Step 4: Verify save and detail view**

- Save the encounter
- Open detail view
- "Me" section shows "Bottom" + "Orgasm"
- Partners section shows "Alex · Top" (no orgasm label)

- [ ] **Step 5: Verify edit round-trip**

- Edit the encounter
- Participants section pre-populates: Me expanded shows Bottom + orgasm on, Alex shows Top
- Change Alex to have orgasm: on, save
- Detail view now shows orgasm for both

- [ ] **Step 6: Commit any fixes**

```bash
git add -A && git commit -m "fix(participants): smoke test fixes"
```

---

## Self-Review

**Spec coverage:**
- ✅ `SQLEncounterPartner.hadOrgasm: Bool` — Task 1
- ✅ Migration 12 `ALTER TABLE encounterPartner ADD COLUMN hadOrgasm INTEGER NOT NULL DEFAULT 0` — Task 2
- ✅ `EncounterService.create/update` gain `partnerOrgasms: [UUID: Bool]` — Task 3
- ✅ `EncountersManager` signatures updated — Task 4
- ✅ `ParticipantsSection` accordion with Me first (AccentColor), each row expands to position + orgasm — Task 5
- ✅ `RatingSection` loses `reachedOrgasm` — Task 6
- ✅ `EncounterFormView` wires `partnerOrgasms` state, loads from junctions, saves — Task 7
- ✅ `EncounterDetailView` shows orgasm alongside position per partner, "Me" section shows position + orgasm — Task 8

**Type consistency:**
- `partnerOrgasms: [UUID: Bool]` used consistently across Tasks 3, 4, 5, 7
- `myReachedOrgasm: Bool` in `ParticipantsSection` binds to `$reachedOrgasm` in `EncounterFormView` — consistent
- `hadOrgasm: Bool` on `SQLEncounterPartner` matches `partnerOrgasms[id] ?? false` in service
- `meID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!` — all-zeros UUID used as sentinel, doesn't collide with any real partner or position UUID

**Placeholder scan:** No TBDs, no "implement later", all code blocks complete.
