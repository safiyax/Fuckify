# Partner Positions Feature — Design Spec

**Date:** 2026-04-15
**Status:** Approved

---

## Overview

Add the ability to record sexual positions per partner and for the user themselves during an encounter. Position is optional, per-partner-per-encounter, and user-customizable (following the existing `activityType` catalog pattern). The user's own position is stored on the encounter itself; each partner's position is stored on the `encounterPartner` junction row.

---

## Data Model

### `SQLPositionType` — table: `positionType`

Mirrors `activityType` / `protectionMethodType` / `stiTestResultType` pattern.

| Column | Type | Notes |
|---|---|---|
| `id` | UUID (TEXT) | Primary key |
| `name` | String | e.g. "Top", "Bottom", "Switch" |
| `icon` | String | SF Symbol name |
| `isBuiltIn` | Bool | Built-ins cannot be deleted |
| `isEnabled` | Bool | User can hide |
| `sortOrder` | Int | Display order |
| `dateAdded` | Date | Record creation timestamp |

**Built-in position types** (stable predefined UUIDs in the `0000...0004xx` range):

| UUID suffix | Name | Icon |
|---|---|---|
| `0401` | Top | `arrow.up.circle.fill` |
| `0402` | Bottom | `arrow.down.circle.fill` |
| `0403` | Switch | `arrow.up.arrow.down.circle.fill` |

### `SQLEncounter` changes

Add one nullable column:
- `positionTypeId: UUID?` — the user's own position for this encounter

### `SQLEncounterPartner` changes

Add one nullable column:
- `positionTypeId: UUID?` — this partner's position in this encounter

---

## Database Migration

**Migration 11:** `AddPositionTypes`

1. Create `positionType` table with the schema above (STRICT, TEXT PRIMARY KEY for id).
2. Seed 3 built-in position types with predefined UUIDs using `arguments:` array (passing `Date()` directly, not ISO8601 string).
3. `ALTER TABLE "encounter" ADD COLUMN "positionTypeId" TEXT` — nullable, no default.
4. `ALTER TABLE "encounterPartner" ADD COLUMN "positionTypeId" TEXT` — nullable, no default.

Existing rows get NULL for both new columns, which maps to `nil` in Swift. No data migration required.

---

## Service Layer

### `PositionTypeService`

New service, registered as `DependencyKey`. Mirrors `STIResultTypeService` exactly.

**Methods:**
- `fetchAll() throws -> [SQLPositionType]` — enabled types sorted by `sortOrder`
- `fetchAllIncludingDisabled() throws -> [SQLPositionType]`
- `create(name:icon:) throws -> UUID` — user-defined types only
- `delete(_ id: UUID) throws` — throws `PositionTypeError.cannotDeleteBuiltIn` or `PositionTypeError.hasAssociatedEncounters` if referenced
- `toggle(_ id: UUID) throws` — flips `isEnabled` in same transaction; raw SQL for built-ins
- `seedDefaults() throws` — idempotent

**`PositionTypeError`:**
```swift
enum PositionTypeError: LocalizedError {
    case cannotDeleteBuiltIn
    case hasAssociatedEncounters
}
```

`hasAssociatedEncounters` checks both `encounter.positionTypeId` and `encounterPartner.positionTypeId` before allowing deletion.

### `EncounterService` changes

Updated signatures:

```swift
func create(
    _ draft: SQLEncounter.Draft,
    partnerIDs: [UUID],
    partnerPositionTypeIDs: [UUID: UUID?],  // partner ID → position type ID
    myPositionTypeId: UUID?,
    activityTypeIDs: [UUID],
    protectionMethodIDs: [UUID]
) throws -> UUID

func update(
    _ encounter: SQLEncounter,
    partnerIDs: [UUID]? = nil,
    partnerPositionTypeIDs: [UUID: UUID?]? = nil,
    myPositionTypeId: UUID?? = nil,          // nil = don't touch; .some(nil) = clear
    activityTypeIDs: [UUID]? = nil,
    protectionMethodIDs: [UUID]? = nil
) throws
```

Inside both methods:
- `positionTypeId` is written to each `encounterPartner` row in the same `database.write` transaction — no re-entrancy risk.
- The `encounter` row update includes `positionTypeId` from `myPositionTypeId`.
- Partners missing from `partnerPositionTypeIDs` get `positionTypeId = NULL`.

### `EncountersManager` changes

Expose `positionTypes: [SQLPositionType]` loaded alongside `activityTypes` and `protectionMethods` on `load()`. No new manager needed.

---

## UI

### `EncounterFormView` changes

Two new sections added to the form:

**New state:**
```swift
@State private var myPositionTypeId: UUID? = nil
@State private var partnerPositionTypeIDs: [UUID: UUID?] = [:]
```

When a partner is removed from `selectedPartnerIDs`, their entry is removed from `partnerPositionTypeIDs`. When re-added, defaults to nil.

**"My Position" section** — appears directly below the partners chip section. A single segmented picker if ≤3 enabled position types, menu picker otherwise, plus a "None" option to clear. Label: "My Position". Hidden if no position types are enabled.

**"Partner Positions" section** — visible only when `selectedPartnerIDs` is non-empty. Lists each selected partner by name with their own inline position picker (same adaptive segmented/menu logic). Defaults to nil (no selection). Hidden if no position types are enabled.

**`saveEncounter()`** — passes `partnerPositionTypeIDs` and `myPositionTypeId` to both `encounterService.create()` and `encounterService.update()`.

### `EncounterDetailView` changes

Show "My Position" and each partner's position if non-nil:
- My position: icon + name badge in the encounter detail.
- Partner position: shown inline next to the partner name/chip.
- Both hidden entirely if nil.

### Customization settings

Position types appear in the existing customization/settings screen alongside activity types and protection methods, using the identical toggle/reorder/add pattern.

---

## Error Handling & Edge Cases

- **Existing encounters** — all existing rows get `positionTypeId = NULL`. UI treats nil as "not set" and shows nothing — no disruption.
- **Partner removed mid-edit** — entry removed from `partnerPositionTypeIDs` immediately on deselect.
- **Deleting a referenced position type** — `PositionTypeService.delete()` checks both `encounter` and `encounterPartner` tables before deleting; throws `hasAssociatedEncounters` if any references exist.
- **All position types disabled** — "My Position" and "Partner Positions" sections hidden entirely in the form. Detail view shows nothing.
- **Double-optional on `myPositionTypeId`** — `nil` = don't touch, `.some(nil)` = clear. Matches existing `EncounterService.update()` pattern for optional fields.
- **Partner missing from `partnerPositionTypeIDs`** — written as NULL. No crash.
- **Built-in position types** — cannot be deleted, only disabled via `toggle()`.

---

## Files to Create

```
Fuckify/Database/Models/SQLPositionType.swift
Fuckify/Database/Services/PositionTypeService.swift
Fuckify/Database/Migrations/AddPositionTypes.swift
```

## Files to Modify

- `Fuckify/Database/AppDatabase.swift` — register Migration 11
- `Fuckify/Database/Models/SQLEncounter.swift` — add `positionTypeId: UUID?` to `SQLEncounterPartner`; add `positionTypeId: UUID?` to `SQLEncounter`
- `Fuckify/Database/Services/EncounterService.swift` — update `create()` and `update()` signatures and implementations
- `Fuckify/Features/Encounter/ViewModels/EncountersManager.swift` — add `positionTypes: [SQLPositionType]`
- `Fuckify/Features/Encounter/Views/EncounterFormView.swift` — add My Position + Partner Positions sections
- `Fuckify/Features/Encounter/Views/EncounterDetailView.swift` — display positions
- Settings/customization screen — add position type management
