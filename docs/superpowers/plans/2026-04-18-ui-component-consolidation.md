# UI Component Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate 14 categories of duplicated SwiftUI code by extracting shared components, reducing approximately 1,500 lines of near-verbatim copy-paste across the codebase.

**Architecture:** New shared components live in `Features/Shared/Components/`. Customization-specific shared pieces live in `Features/Settings/Customization/Components/` (which already exists for `SFSymbolPickerView`). Existing view files are updated to use the new components in-place; no files are moved or renamed unless explicitly stated.

**Tech Stack:** SwiftUI, Swift 5.9+, `@Observable` (iOS 17+), GRDB/SQLiteData, Dependencies

---

## Task Order Overview

Tasks are ordered from lowest-risk to highest-risk and from most self-contained to most sweeping:

1. `BuiltInBadge` — tiny, used in 4 places, zero logic
2. `PartnerAvatar` — pure display, used in 7+ places
3. `SettingsRow` — pure display, used in 12 places
4. Duration picker fix — use existing component instead of inline duplicate
5. `PINEntryPad` — extract within SecurityView.swift
6. `CustomizationItemRow` — uses `BuiltInBadge`, unifies 4 rows
7. `IconPickerRow` — extract from form views
8. Customization form consolidation — uses `IconPickerRow`
9. Customization settings consolidation — uses `CustomizationItemRow`
10. `PartnerChip` consolidation — unifies 4 chip variants

---

## Task 1: Extract `BuiltInBadge` Component

The `Text("Built-in")` badge is copy-pasted verbatim across four row views. Extract it to a shared file.

**Files:**
- Create: `Fuckify/Features/Shared/Components/BuiltInBadge.swift`
- Modify: `Fuckify/Features/Settings/Customization/Activities/ActivitiesSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodsSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/PartnerAttributes/PartnerAttributesSettingsView.swift`

- [ ] **Step 1: Create the Shared/Components directory and BuiltInBadge.swift**

```swift
// Fuckify/Features/Shared/Components/BuiltInBadge.swift

import SwiftUI

/// A small pill badge indicating a built-in (non-deletable) item.
struct BuiltInBadge: View {
    var body: some View {
        Text("Built-in")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }
}

#Preview {
    BuiltInBadge()
        .padding()
}
```

- [ ] **Step 2: Replace the badge in ActivityRow inside ActivitiesSettingsView.swift**

Find this block in `ActivityRow.body` (inside `ActivitiesSettingsView.swift`):
```swift
if activity.isBuiltIn {
    Text("Built-in")
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
}
```
Replace with:
```swift
if activity.isBuiltIn {
    BuiltInBadge()
}
```

- [ ] **Step 3: Replace the badge in ProtectionMethodRow inside ProtectionMethodsSettingsView.swift**

Find this block in `ProtectionMethodRow.body`:
```swift
if method.isBuiltIn {
    Text("Built-in")
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
}
```
Replace with:
```swift
if method.isBuiltIn {
    BuiltInBadge()
}
```

- [ ] **Step 4: Replace the badge in PositionRow inside PositionsSettingsView.swift**

Find this block in `PositionRow.body`:
```swift
if position.isBuiltIn {
    Text("Built-in")
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
}
```
Replace with:
```swift
if position.isBuiltIn {
    BuiltInBadge()
}
```

- [ ] **Step 5: Replace the badge in AttributeRow inside PartnerAttributesSettingsView.swift**

Find this block in `AttributeRow.body` (inside the `HStack(spacing: 4)` in the VStack):
```swift
if attribute.isBuiltIn {
    Text("Built-in")
        .font(.caption2)
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
}
```
Replace with:
```swift
if attribute.isBuiltIn {
    BuiltInBadge()
}
```

- [ ] **Step 6: Build the project and confirm no errors**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|warning:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Shared/Components/BuiltInBadge.swift \
        Fuckify/Features/Settings/Customization/Activities/ActivitiesSettingsView.swift \
        Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodsSettingsView.swift \
        Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift \
        Fuckify/Features/Settings/Customization/PartnerAttributes/PartnerAttributesSettingsView.swift
git commit -m "refactor: extract BuiltInBadge component to eliminate 4x verbatim duplication"
```

---

## Task 2: Extract `PartnerAvatar` Component

The colored circle with initials pattern is repeated in 7+ places across Partner and Encounter views. Extract it to a shared component.

**Files:**
- Create: `Fuckify/Features/Shared/Components/PartnerAvatar.swift`
- Modify: `Fuckify/Features/Partner/Components/PartnerAvatarHeader.swift`
- Modify: `Fuckify/Features/Partner/Components/PartnerPickerRow.swift`
- Modify: `Fuckify/Features/Partner/Views/PartnersListView.swift`
- Modify: `Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift`
- Modify: `Fuckify/Features/Statistics/Views/StatisticsView.swift`
- Modify: `Fuckify/Features/Encounter/Views/ActiveEncounterView.swift`

- [ ] **Step 1: Read the current avatar usage in each file to confirm exact sizes and font choices**

Read these files to understand current usage:
- `Fuckify/Features/Partner/Components/PartnerAvatarHeader.swift`
- `Fuckify/Features/Partner/Components/PartnerPickerRow.swift`
- `Fuckify/Features/Partner/Views/PartnersListView.swift`
- `Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift`
- `Fuckify/Features/Statistics/Views/StatisticsView.swift`
- `Fuckify/Features/Encounter/Views/ActiveEncounterView.swift`

- [ ] **Step 2: Create PartnerAvatar.swift**

```swift
// Fuckify/Features/Shared/Components/PartnerAvatar.swift

import SwiftUI

/// A colored circle displaying a partner's initials, used wherever a partner is represented visually.
/// Font size scales automatically with the circle size.
struct PartnerAvatar: View {
    let color: Color
    let initials: String
    let size: CGFloat

    /// Convenience initialiser for SQLPartner — derives color and initials automatically.
    init(color: Color, initials: String, size: CGFloat = 50) {
        self.color = color
        self.initials = initials
        self.size = size
    }

    private var fontSize: CGFloat {
        switch size {
        case ..<30: return 10
        case 30..<45: return 14
        case 45..<60: return 18
        case 60..<80: return 24
        case 80..<100: return 32
        default: return size * 0.38
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        PartnerAvatar(color: .blue, initials: "AB", size: 32)
        PartnerAvatar(color: .pink, initials: "CD", size: 50)
        PartnerAvatar(color: .purple, initials: "EF", size: 96)
        PartnerAvatar(color: .green, initials: "GH", size: 100)
    }
    .padding()
}
```

- [ ] **Step 3: Update each call site**

For every file listed above, find the inline `ZStack { Circle()...frame(width:X,height:X); Text(initials)... }` pattern and replace it with `PartnerAvatar(color: <color>, initials: <initials>, size: <X>)`.

Exact replacements by file:

**PartnerAvatarHeader.swift** — find the large circle (size ~100) and replace.

**PartnerPickerRow.swift** — find the circle (size 40) and replace.

**PartnersListView.swift `PartnerRowView`** — find the circle (size 50) and replace.

**PartnersListView.swift `PinnedPartnerView`** — find the large circle (size 96) and replace.

**PositionsSelectionSection.swift `ParticipantHeaderRow`** — find the circle (size 32) and replace.

**StatisticsView.swift `TopPartnersSection`** — find the circle (size 50) and replace.

**ActiveEncounterView.swift `PartnerDisplayChip`** — find the circle (size 32) and replace.

- [ ] **Step 4: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|warning:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Shared/Components/PartnerAvatar.swift \
        Fuckify/Features/Partner/Components/PartnerAvatarHeader.swift \
        Fuckify/Features/Partner/Components/PartnerPickerRow.swift \
        Fuckify/Features/Partner/Views/PartnersListView.swift \
        Fuckify/Features/Encounter/Components/PositionsSelectionSection.swift \
        Fuckify/Features/Statistics/Views/StatisticsView.swift \
        Fuckify/Features/Encounter/Views/ActiveEncounterView.swift
git commit -m "refactor: extract PartnerAvatar component, replace 7 inline circle+initials implementations"
```

---

## Task 3: Extract `SettingsRow` Component

The `HStack { Image(systemName:).foregroundColor(X); Text("Label") }` pattern is used as a NavigationLink label 11 times in `SettingsView.swift` and 4 times in `DeleteDataView.swift`.

**Files:**
- Create: `Fuckify/Features/Shared/Components/SettingsRow.swift`
- Modify: `Fuckify/Features/Settings/Views/SettingsView.swift`
- Modify: `Fuckify/Features/Settings/DataManagement/DeleteDataView.swift`

- [ ] **Step 1: Read DeleteDataView.swift to understand its usage**

Read `Fuckify/Features/Settings/DataManagement/DeleteDataView.swift` in full.

- [ ] **Step 2: Create SettingsRow.swift**

```swift
// Fuckify/Features/Shared/Components/SettingsRow.swift

import SwiftUI

/// A standard icon + label row used in Settings lists.
/// Use inside a `NavigationLink` label or standalone `Button` label.
struct SettingsRow: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
        }
    }
}

#Preview {
    List {
        NavigationLink(destination: EmptyView()) {
            SettingsRow(icon: "heart.fill", color: .pink, label: "Support the App")
        }
        NavigationLink(destination: EmptyView()) {
            SettingsRow(icon: "shield.fill", color: .green, label: "Protection Methods")
        }
    }
}
```

- [ ] **Step 3: Replace all HStack label patterns in SettingsView.swift**

In `SettingsView.swift`, replace each `HStack { Image(systemName: "X").foregroundColor(.Y); Text("Z") }` used as a NavigationLink or Button label with `SettingsRow(icon: "X", color: .Y, label: "Z")`.

There are 11 occurrences. Do all of them. For example:

```swift
// BEFORE
NavigationLink {
    AppIconSettingsView()
} label: {
    HStack {
        Image(systemName: "app.fill")
            .foregroundColor(.pink)
        Text("App Icon")
    }
}

// AFTER
NavigationLink {
    AppIconSettingsView()
} label: {
    SettingsRow(icon: "app.fill", color: .pink, label: "App Icon")
}
```

Apply the same pattern to all remaining NavigationLinks and Buttons:
- `"heart.circle.fill"` / `.purple` / `"Activities"`
- `"shield.fill"` / `.green` / `"Protection Methods"`
- `"arrow.up.arrow.down.circle.fill"` / `.orange` / `"Positions"`
- `"person.crop.circle.badge.ellipsis"` / `.accentColor` / `"Partner Attributes"`
- `"lock.fill"` / `.orange` / `"Security"`
- `"arrow.up.arrow.down"` / `.blue` / `"Import & Export"`
- `"trash.fill"` / `.red` / `"Delete Data"`
- `"info.circle.fill"` / `.blue` / `"About"`
- `"heart.fill"` / `.pink` / `"Support the App"`
- Any remaining ones found when reading the file

- [ ] **Step 4: Replace HStack label patterns in DeleteDataView.swift**

Apply the same `SettingsRow(icon:color:label:)` replacement to the ~4 occurrences in `DeleteDataView.swift`.

- [ ] **Step 5: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Shared/Components/SettingsRow.swift \
        Fuckify/Features/Settings/Views/SettingsView.swift \
        Fuckify/Features/Settings/DataManagement/DeleteDataView.swift
git commit -m "refactor: extract SettingsRow component, replace 15 inline icon+label HStacks in settings"
```

---

## Task 4: Fix Duration Picker Duplication (Quick Win)

`DurationPickerSection.swift` already exists as a reusable component. `EncounterFormView.swift` ignores it and inlines the identical pickers. The inline version wraps them in the same `Section("When")` that `DurationPickerSection` provides, but `EncounterFormView` puts other content (the `DatePicker`) in that same section. The fix: extract a `DurationPickerRow` that is just the HStack (no Section wrapper), use it in both places.

**Files:**
- Modify: `Fuckify/Features/Encounter/Components/DurationPickerSection.swift`
- Modify: `Fuckify/Features/Encounter/Views/EncounterFormView.swift`

- [ ] **Step 1: Add DurationPickerRow to DurationPickerSection.swift**

Open `DurationPickerSection.swift`. Add a new `DurationPickerRow` view below the existing `DurationPickerSection`, which is just the `HStack` content without the `Section` wrapper:

```swift
// Fuckify/Features/Encounter/Components/DurationPickerSection.swift
// ADD after the existing DurationPickerSection struct:

/// Just the duration HStack (hours + minutes pickers) without a Section wrapper.
/// Use this when you need to embed the duration pickers inside an existing Section.
struct DurationPickerRow: View {
    @Binding var durationHours: Int
    @Binding var durationMinutes: Int

    var body: some View {
        HStack {
            Text("Duration")
            Spacer()
            Picker(selection: $durationHours, label: EmptyView()) {
                ForEach(0..<24) { hour in
                    Text("\(hour)h").tag(hour)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Hours")
            .accessibilityValue("\(durationHours) hours")

            Picker(selection: $durationMinutes, label: EmptyView()) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text("\(minute)m").tag(minute)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Minutes")
            .accessibilityValue("\(durationMinutes) minutes")
        }
    }
}
```

Also update the existing `DurationPickerSection` to use `DurationPickerRow` internally:

```swift
struct DurationPickerSection: View {
    @Binding var durationHours: Int
    @Binding var durationMinutes: Int

    var body: some View {
        Section("When") {
            DurationPickerRow(durationHours: $durationHours, durationMinutes: $durationMinutes)
        }
    }
}
```

- [ ] **Step 2: Replace the inline duration pickers in EncounterFormView.swift**

In `EncounterFormView.swift`, find the `Section("When")` block that contains both a `DatePicker` and an inline `HStack` for duration (lines ~73–93):

```swift
// BEFORE (inside Section("When"))
Section("When") {
    DatePicker("Date", selection: $date, displayedComponents: .date)
        .datePickerStyle(.compact)
    
    HStack {
        Text("Duration")
        Spacer()
        Picker(selection: $durationHours, label: EmptyView()) {
            ForEach(0..<24) { hour in
                Text("\(hour)h").tag(hour)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Hours")
        .accessibilityValue("\(durationHours) hours")

        Picker(selection: $durationMinutes, label: EmptyView()) {
            ForEach([0, 15, 30, 45], id: \.self) { minute in
                Text("\(minute)m").tag(minute)
            }
        }
        .pickerStyle(.menu)
        .accessibilityLabel("Minutes")
        .accessibilityValue("\(durationMinutes) minutes")
    }
}
```

Replace with:

```swift
// AFTER
Section("When") {
    DatePicker("Date", selection: $date, displayedComponents: .date)
        .datePickerStyle(.compact)
    
    DurationPickerRow(durationHours: $durationHours, durationMinutes: $durationMinutes)
}
```

- [ ] **Step 3: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Encounter/Components/DurationPickerSection.swift \
        Fuckify/Features/Encounter/Views/EncounterFormView.swift
git commit -m "refactor: add DurationPickerRow, eliminate inline duration picker duplication in EncounterFormView"
```

---

## Task 5: Extract `PINEntryPad` Component

`SecurityView.swift` contains two structs (`PINSetupView` and `PINRemovalView`) that both have a verbatim copy of the PIN dot indicator and 3×3+0+delete number pad. Extract both into a `PINEntryPad` component within the same file.

**Files:**
- Modify: `Fuckify/Features/Settings/Security/SecurityView.swift`

- [ ] **Step 1: Add PINDots and PINEntryPad to SecurityView.swift**

After the `NumberButton` struct at the bottom of `SecurityView.swift`, add:

```swift
// MARK: - PIN Dots Indicator

private struct PINDots: View {
    let count: Int
    let accentColor: Color
    let total: Int

    var body: some View {
        HStack(spacing: 20) {
            ForEach(0..<total, id: \.self) { index in
                Circle()
                    .fill(count > index ? accentColor : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 20)
            }
        }
        .padding(.vertical)
    }
}

// MARK: - PIN Number Pad

private struct PINNumberPad: View {
    let onDigit: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 16) {
                    ForEach(1..<4) { col in
                        let number = row * 3 + col
                        NumberButton(number: "\(number)") {
                            onDigit("\(number)")
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                Color.clear
                    .frame(width: 80, height: 80)

                NumberButton(number: "0") {
                    onDigit("0")
                }

                Button {
                    onDelete()
                } label: {
                    Image(systemName: "delete.left.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 80, height: 80)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(40)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Replace the PIN dots in PINSetupView**

In `PINSetupView.body`, find the `// PIN Display` section:

```swift
// PIN Display
HStack(spacing: 20) {
    ForEach(0..<4, id: \.self) { index in
        Circle()
            .fill(getCurrentPIN().count > index ? Color.blue : Color.gray.opacity(0.3))
            .frame(width: 20, height: 20)
    }
}
.padding(.vertical)
```

Replace with:

```swift
// PIN Display
PINDots(count: getCurrentPIN().count, accentColor: .blue, total: 4)
```

- [ ] **Step 3: Replace the number pad in PINSetupView**

In `PINSetupView.body`, find the `// Number Pad` section (the entire `VStack(spacing: 16)` containing three `ForEach` rows and the bottom row with 0 and delete):

```swift
// Number Pad
VStack(spacing: 16) {
    ForEach(0..<3) { row in
        HStack(spacing: 16) {
            ForEach(1..<4) { col in
                let number = row * 3 + col
                NumberButton(number: "\(number)") {
                    addDigit("\(number)")
                }
            }
        }
    }
    
    HStack(spacing: 16) {
        Color.clear
            .frame(width: 80, height: 80)
        
        NumberButton(number: "0") {
            addDigit("0")
        }
        
        Button {
            deleteDigit()
        } label: {
            Image(systemName: "delete.left.fill")
                .font(.title2)
                .foregroundColor(.red)
                .frame(width: 80, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(40)
        }
    }
}
```

Replace with:

```swift
// Number Pad
PINNumberPad(
    onDigit: { addDigit($0) },
    onDelete: { deleteDigit() }
)
```

- [ ] **Step 4: Replace the PIN dots in PINRemovalView**

In `PINRemovalView.body`, find the `// PIN Display` section:

```swift
// PIN Display
HStack(spacing: 20) {
    ForEach(0..<4, id: \.self) { index in
        Circle()
            .fill(pin.count > index ? Color.red : Color.gray.opacity(0.3))
            .frame(width: 20, height: 20)
    }
}
.padding(.vertical)
```

Replace with:

```swift
// PIN Display
PINDots(count: pin.count, accentColor: .red, total: 4)
```

- [ ] **Step 5: Replace the number pad in PINRemovalView**

In `PINRemovalView.body`, find the same `// Number Pad` VStack block and replace it with:

```swift
// Number Pad
PINNumberPad(
    onDigit: { addDigit($0) },
    onDelete: { deleteDigit() }
)
```

- [ ] **Step 6: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Settings/Security/SecurityView.swift
git commit -m "refactor: extract PINDots and PINNumberPad, eliminate verbatim duplication in PINSetupView and PINRemovalView"
```

---

## Task 6: Extract `CustomizationItemRow` Component

The four customization row views (`ActivityRow`, `ProtectionMethodRow`, `PositionRow`, `AttributeRow`) share the same layout. Create a single reusable `CustomizationItemRow` in the shared Customization components folder.

`AttributeRow` also shows a field-type badge; that extra badge is supported via an optional `extraBadge` parameter.

**Files:**
- Create: `Fuckify/Features/Settings/Customization/Components/CustomizationItemRow.swift`
- Modify: `Fuckify/Features/Settings/Customization/Activities/ActivitiesSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodsSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/PartnerAttributes/PartnerAttributesSettingsView.swift`

- [ ] **Step 1: Create CustomizationItemRow.swift**

```swift
// Fuckify/Features/Settings/Customization/Components/CustomizationItemRow.swift

import SwiftUI

/// A standard row for customization settings lists.
/// Shows an icon, a name, an optional "Built-in" badge, an optional extra badge, and a toggle.
struct CustomizationItemRow: View {
    let icon: String
    let name: String
    let isEnabled: Bool
    let isBuiltIn: Bool
    let accentColor: Color
    /// An optional extra badge label shown after the Built-in badge (e.g. field type).
    var extraBadge: String? = nil
    /// An optional extra badge background color.
    var extraBadgeColor: Color = .purple
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isEnabled ? accentColor : .gray)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundColor(isEnabled ? .primary : .secondary)

                if isBuiltIn || extraBadge != nil {
                    HStack(spacing: 4) {
                        if isBuiltIn {
                            BuiltInBadge()
                        }
                        if let badge = extraBadge {
                            Text(badge)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(extraBadgeColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("\(name) enabled")
        }
        .padding(.vertical, isBuiltIn ? 0 : 2)
    }
}

#Preview {
    List {
        CustomizationItemRow(
            icon: "heart.fill",
            name: "Kissing",
            isEnabled: true,
            isBuiltIn: false,
            accentColor: .purple,
            onToggle: {}
        )
        CustomizationItemRow(
            icon: "shield.fill",
            name: "Condom",
            isEnabled: true,
            isBuiltIn: true,
            accentColor: .green,
            onToggle: {}
        )
        CustomizationItemRow(
            icon: "star.fill",
            name: "Partner Rating",
            isEnabled: false,
            isBuiltIn: false,
            accentColor: .accentColor,
            extraBadge: "Number",
            extraBadgeColor: .purple,
            onToggle: {}
        )
    }
}
```

- [ ] **Step 2: Replace ActivityRow body in ActivitiesSettingsView.swift**

Find the entire `ActivityRow` struct and replace it:

```swift
// BEFORE
struct ActivityRow: View {
    let activity: SQLActivityTypeEntity
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundColor(activity.isEnabled ? .purple : .gray)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.name)
                    .font(.body)
                    .foregroundColor(activity.isEnabled ? .primary : .secondary)
                
                if activity.isBuiltIn {
                    BuiltInBadge()
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { activity.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("\(activity.name) enabled")
        }
        .padding(.vertical, !activity.isBuiltIn ? 2 : 0)
    }
}
```

```swift
// AFTER
private struct ActivityRow: View {
    let activity: SQLActivityTypeEntity
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: activity.icon,
            name: activity.name,
            isEnabled: activity.isEnabled,
            isBuiltIn: activity.isBuiltIn,
            accentColor: .purple,
            onToggle: onToggle
        )
    }
}
```

- [ ] **Step 3: Replace ProtectionMethodRow in ProtectionMethodsSettingsView.swift**

```swift
// AFTER
private struct ProtectionMethodRow: View {
    let method: SQLProtectionMethodEntity
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: method.icon,
            name: method.name,
            isEnabled: method.isEnabled,
            isBuiltIn: method.isBuiltIn,
            accentColor: .green,
            onToggle: onToggle
        )
    }
}
```

- [ ] **Step 4: Replace PositionRow in PositionsSettingsView.swift**

```swift
// AFTER
private struct PositionRow: View {
    let position: SQLPositionType
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: position.icon,
            name: position.name,
            isEnabled: position.isEnabled,
            isBuiltIn: position.isBuiltIn,
            accentColor: .orange,
            onToggle: onToggle
        )
    }
}
```

- [ ] **Step 5: Replace AttributeRow in PartnerAttributesSettingsView.swift**

```swift
// AFTER
private struct AttributeRow: View {
    let attribute: SQLPartnerAttributeType
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: attribute.icon,
            name: attribute.name,
            isEnabled: attribute.isEnabled,
            isBuiltIn: attribute.isBuiltIn,
            accentColor: .accentColor,
            extraBadge: attribute.parsedFieldType.displayName,
            extraBadgeColor: .purple,
            onToggle: onToggle
        )
    }
}
```

- [ ] **Step 6: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Settings/Customization/Components/CustomizationItemRow.swift \
        Fuckify/Features/Settings/Customization/Activities/ActivitiesSettingsView.swift \
        Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodsSettingsView.swift \
        Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift \
        Fuckify/Features/Settings/Customization/PartnerAttributes/PartnerAttributesSettingsView.swift
git commit -m "refactor: extract CustomizationItemRow, replace 4 near-identical list row implementations"
```

---

## Task 7: Extract `IconPickerRow` Component

The icon picker button inside the three customization form views (`ActivityFormView`, `ProtectionMethodFormView`, `PositionFormView`) is verbatim copy-paste. Extract it to the shared Customization components folder.

**Files:**
- Create: `Fuckify/Features/Settings/Customization/Components/IconPickerRow.swift`
- Modify: `Fuckify/Features/Settings/Customization/Activities/ActivityFormView.swift`
- Modify: `Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodFormView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift`

- [ ] **Step 1: Create IconPickerRow.swift**

```swift
// Fuckify/Features/Settings/Customization/Components/IconPickerRow.swift

import SwiftUI

/// A tappable row that shows the currently selected SF Symbol and opens the picker.
/// Used in customization item form views (activities, protection methods, positions).
struct IconPickerRow: View {
    @Binding var selectedIcon: String
    let accentColor: Color
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            if !isDisabled {
                onTap()
            }
        } label: {
            HStack {
                Image(systemName: selectedIcon)
                    .foregroundColor(accentColor)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(8)

                Text("Choose Icon")
                    .foregroundColor(isDisabled ? .secondary : .primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(isDisabled)
    }
}

#Preview {
    Form {
        Section("Icon") {
            IconPickerRow(
                selectedIcon: .constant("heart.fill"),
                accentColor: .purple,
                isDisabled: false,
                onTap: {}
            )
        }
        Section("Icon (disabled)") {
            IconPickerRow(
                selectedIcon: .constant("shield.fill"),
                accentColor: .green,
                isDisabled: true,
                onTap: {}
            )
        }
    }
}
```

- [ ] **Step 2: Replace the icon picker button in ActivityFormView.swift**

In `ActivityFormView.body`, find the `Section("Icon")`:

```swift
Section("Icon") {
    Button {
        if !isBuiltIn {
            showingIconPicker = true
        }
    } label: {
        HStack {
            Image(systemName: selectedIcon)
                .foregroundColor(.purple)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(8)
            
            Text("Choose Icon")
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    .disabled(isBuiltIn)
    
    if isBuiltIn {
        Text("Built-in activity icons cannot be changed")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

Replace with:

```swift
Section("Icon") {
    IconPickerRow(
        selectedIcon: $selectedIcon,
        accentColor: .purple,
        isDisabled: isBuiltIn,
        onTap: { showingIconPicker = true }
    )

    if isBuiltIn {
        Text("Built-in activity icons cannot be changed")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

- [ ] **Step 3: Replace the icon picker button in ProtectionMethodFormView.swift**

Find the `Section("Icon")` in `ProtectionMethodFormView.body` and replace with:

```swift
Section("Icon") {
    IconPickerRow(
        selectedIcon: $selectedIcon,
        accentColor: .green,
        isDisabled: isBuiltIn,
        onTap: { showingIconPicker = true }
    )

    if isBuiltIn {
        Text("Built-in protection method icons cannot be changed")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

- [ ] **Step 4: Replace the icon picker button in PositionFormView.swift**

Find the `Section("Icon")` in `PositionFormView.body` and replace with:

```swift
Section("Icon") {
    IconPickerRow(
        selectedIcon: $selectedIcon,
        accentColor: .orange,
        isDisabled: isBuiltIn,
        onTap: { showingIconPicker = true }
    )

    if isBuiltIn {
        Text("Built-in position icons cannot be changed")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

- [ ] **Step 5: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Settings/Customization/Components/IconPickerRow.swift \
        Fuckify/Features/Settings/Customization/Activities/ActivityFormView.swift \
        Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodFormView.swift \
        Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift
git commit -m "refactor: extract IconPickerRow, eliminate 3 verbatim copy-paste icon picker buttons"
```

---

## Task 8: Consolidate Customization Form Views into `CustomizationItemFormView`

The three form views (`ActivityFormView`, `ProtectionMethodFormView`, `PositionFormView`) are structurally identical. Consolidate them into a single generic `CustomizationItemFormView` that accepts closures for the save operation. The existing views become thin wrappers so call sites don't need to change.

**Files:**
- Create: `Fuckify/Features/Settings/Customization/Components/CustomizationItemFormView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Activities/ActivityFormView.swift`
- Modify: `Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodFormView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift`

- [ ] **Step 1: Create CustomizationItemFormView.swift**

```swift
// Fuckify/Features/Settings/Customization/Components/CustomizationItemFormView.swift

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "CustomizationItemForm")

/// The shared form body used by ActivityFormView, ProtectionMethodFormView, and PositionFormView.
///
/// - Parameters:
///   - itemType:       Human-readable noun used in titles and error messages (e.g. "Activity").
///   - defaultIcon:    The SF Symbol name to use when creating a new item.
///   - accentColor:    Tint color applied to the icon picker and other accent elements.
///   - existingName:   Pre-filled name when editing; nil when creating.
///   - existingIcon:   Pre-filled icon when editing; nil when creating.
///   - isBuiltIn:      When true, name and icon fields are read-only.
///   - onSave:         Called with (name, icon) when the form is submitted.
///                     Throw to show an error. Not called for built-in items (they dismiss immediately).
struct CustomizationItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let itemType: String
    let defaultIcon: String
    let accentColor: Color
    let isEditing: Bool
    let isBuiltIn: Bool
    let onSave: (String, String) throws -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var errorMessage: String?

    init(
        itemType: String,
        defaultIcon: String,
        accentColor: Color,
        existingName: String? = nil,
        existingIcon: String? = nil,
        isBuiltIn: Bool = false,
        onSave: @escaping (String, String) throws -> Void
    ) {
        self.itemType = itemType
        self.defaultIcon = defaultIcon
        self.accentColor = accentColor
        self.isEditing = existingName != nil
        self.isBuiltIn = isBuiltIn
        self.onSave = onSave
        _name = State(initialValue: existingName ?? "")
        _selectedIcon = State(initialValue: existingIcon ?? defaultIcon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("\(itemType) Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if isBuiltIn {
                        Text("Built-in \(itemType.lowercased())s cannot be renamed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Icon") {
                    IconPickerRow(
                        selectedIcon: $selectedIcon,
                        accentColor: accentColor,
                        isDisabled: isBuiltIn,
                        onTap: { showingIconPicker = true }
                    )

                    if isBuiltIn {
                        Text("Built-in \(itemType.lowercased()) icons cannot be changed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit \(itemType)" : "Add \(itemType)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
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
        guard !isBuiltIn else { dismiss(); return }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a name"
            return
        }

        do {
            try onSave(trimmed, selectedIcon)
            logger.info("\(isEditing ? "Updated" : "Created") \(itemType.lowercased())")
            dismiss()
        } catch {
            logger.error("Failed to save \(itemType.lowercased()): \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
```

- [ ] **Step 2: Rewrite ActivityFormView.swift to delegate to CustomizationItemFormView**

Replace the entire `body` of `ActivityFormView` (keep the `init`, `isEditing`, `isBuiltIn` computed vars, and `saveActivity()` method, but replace the body):

```swift
// Fuckify/Features/Settings/Customization/Activities/ActivityFormView.swift
// Replace body with:

var body: some View {
    CustomizationItemFormView(
        itemType: "Activity",
        defaultIcon: "heart.fill",
        accentColor: .purple,
        existingName: existingActivity?.name,
        existingIcon: existingActivity?.icon,
        isBuiltIn: isBuiltIn
    ) { name, icon in
        try saveActivity(name: name, icon: icon)
    }
}
```

Also update `saveActivity()` to accept parameters instead of reading from `@State`:

```swift
private func saveActivity(name: String, icon: String) throws {
    let customizationService = CustomizationService()

    if let existing = existingActivity {
        var updated = existing
        updated.name = name
        updated.icon = icon
        try customizationService.updateActivityType(updated)
    } else {
        let existing = (try? customizationService.fetchAllActivityTypes()) ?? []
        if existing.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            throw CustomizationFormError.duplicateName("An activity with this name already exists")
        }
        _ = try customizationService.createActivityType(name: name, icon: icon)
    }
    onSave()
}
```

Add the error type above `ActivityFormView` or in the file:

```swift
enum CustomizationFormError: LocalizedError {
    case duplicateName(String)
    var errorDescription: String? {
        switch self { case .duplicateName(let msg): return msg }
    }
}
```

Remove the `@State private var name`, `@State private var selectedIcon`, `@State private var showingIconPicker`, `@State private var errorMessage` properties since they are now owned by `CustomizationItemFormView`. Keep `existingActivity`, `onSave`, `init`, `isEditing`, `isBuiltIn`, `@Environment(\.dismiss)`, and `@Dependency(\.defaultDatabase)` (if still needed).

- [ ] **Step 3: Rewrite ProtectionMethodFormView.swift to delegate to CustomizationItemFormView**

Apply the same pattern: replace the body and update `saveMethod()` to accept `(name: String, icon: String) throws`:

```swift
var body: some View {
    CustomizationItemFormView(
        itemType: "Protection Method",
        defaultIcon: "shield.fill",
        accentColor: .green,
        existingName: existingMethod?.name,
        existingIcon: existingMethod?.icon,
        isBuiltIn: isBuiltIn
    ) { name, icon in
        try saveMethod(name: name, icon: icon)
    }
}

private func saveMethod(name: String, icon: String) throws {
    let customizationService = CustomizationService()

    if let existing = existingMethod {
        var updated = existing
        updated.name = name
        updated.icon = icon
        try customizationService.updateProtectionMethod(updated)
    } else {
        let existing = (try? customizationService.fetchAllProtectionMethods()) ?? []
        if existing.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            throw CustomizationFormError.duplicateName("A protection method with this name already exists")
        }
        _ = try customizationService.createProtectionMethod(name: name, icon: icon)
    }
    onSave()
}
```

- [ ] **Step 4: Rewrite PositionFormView.swift to delegate to CustomizationItemFormView**

```swift
var body: some View {
    CustomizationItemFormView(
        itemType: "Position",
        defaultIcon: "figure.stand",
        accentColor: .orange,
        existingName: existingPosition?.name,
        existingIcon: existingPosition?.icon,
        isBuiltIn: isBuiltIn
    ) { name, icon in
        try save(name: name, icon: icon)
    }
}

private func save(name: String, icon: String) throws {
    let service = PositionTypeService()
    if let existing = existingPosition {
        var updated = existing
        updated.name = name
        updated.icon = icon
        try service.update(updated)
    } else {
        _ = try service.create(name: name, icon: icon)
    }
    onSave()
}
```

- [ ] **Step 5: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Settings/Customization/Components/CustomizationItemFormView.swift \
        Fuckify/Features/Settings/Customization/Activities/ActivityFormView.swift \
        Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodFormView.swift \
        Fuckify/Features/Settings/Customization/Positions/PositionFormView.swift
git commit -m "refactor: extract CustomizationItemFormView, consolidate 3 near-identical form views"
```

---

## Task 9: Consolidate Customization Settings Views

The four settings list views (`ActivitiesSettingsView`, `ProtectionMethodsSettingsView`, `PositionsSettingsView`, `PartnerAttributesSettingsView`) share an identical structural skeleton. Create a generic `CustomizationSettingsView` and make each existing view a thin initializer call.

**Note:** This task modifies the four settings view files significantly. Each existing view will be reduced to a thin wrapper that calls `CustomizationSettingsView`. The `loadItems`, `toggle`, and `delete` operations remain type-specific in each file.

**Files:**
- Create: `Fuckify/Features/Settings/Customization/Components/CustomizationSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Activities/ActivitiesSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodsSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift`
- Modify: `Fuckify/Features/Settings/Customization/PartnerAttributes/PartnerAttributesSettingsView.swift`

- [ ] **Step 1: Create CustomizationSettingsView.swift**

```swift
// Fuckify/Features/Settings/Customization/Components/CustomizationSettingsView.swift

import SwiftUI

/// A protocol all customizable item types must conform to for use with CustomizationSettingsView.
protocol CustomizableItem: Identifiable where ID == UUID {
    var id: UUID { get }
    var icon: String { get }
    var name: String { get }
    var isEnabled: Bool { get }
    var isBuiltIn: Bool { get }
}

/// Generic settings list view shared by all customization settings screens.
///
/// The host view provides:
/// - `items`: the current list (already split into built-in / custom by computed properties here)
/// - `addSheet`: the form sheet to add a new item (shown when the + button is tapped)
/// - `editSheet`: the form sheet to edit an item (shown when swipe-edit is triggered)
/// - `itemRow`: how each item is rendered (typically `CustomizationItemRow`)
/// - Callbacks: `onToggle`, `onDelete`
struct CustomizationSettingsView<
    Item: CustomizableItem,
    AddSheet: View,
    EditSheet: View,
    RowContent: View
>: View {

    let navigationTitle: String
    let itemTypeName: String        // e.g. "Activity" — used in alert text
    let descriptionText: String
    let accentColor: Color
    let items: [Item]

    let onToggle: (Item) -> Void
    let onDelete: (Item) -> Void

    @ViewBuilder let addSheet: () -> AddSheet
    @ViewBuilder let editSheet: (Item) -> EditSheet
    @ViewBuilder let itemRow: (Item, @escaping () -> Void) -> RowContent

    @State private var showingAdd = false
    @State private var itemToEdit: Item?
    @State private var itemToDelete: Item?
    @State private var showingDeleteAlert = false

    private var builtInItems: [Item] { items.filter { $0.isBuiltIn } }
    private var customItems: [Item] { items.filter { !$0.isBuiltIn } }

    var body: some View {
        List {
            Section {
                Text(descriptionText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if !builtInItems.isEmpty {
                Section("Built-in \(navigationTitle)") {
                    ForEach(builtInItems) { item in
                        itemRow(item, { onToggle(item) })
                    }
                }
            }

            Section {
                ForEach(customItems) { item in
                    itemRow(item, { onToggle(item) })
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)

                            Button {
                                itemToEdit = item
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }

                Button {
                    showingAdd = true
                } label: {
                    Label("Add Custom \(itemTypeName)", systemImage: "plus.circle.fill")
                        .foregroundColor(.accentColor)
                }
            } header: {
                Text("Custom \(navigationTitle)")
            } footer: {
                if customItems.isEmpty {
                    Text("Tap + to add your own custom \(navigationTitle.lowercased())")
                        .font(.caption)
                }
            }
        }
        .tint(accentColor)
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            addSheet()
                .tint(accentColor)
        }
        .sheet(item: $itemToEdit) { item in
            editSheet(item)
                .tint(accentColor)
        }
        .alert("Delete \(itemTypeName)", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = itemToDelete { onDelete(item) }
            }
        } message: {
            Text("Are you sure you want to delete this custom \(itemTypeName.lowercased())?")
        }
    }
}
```

- [ ] **Step 2: Add CustomizableItem conformances**

Each model type needs to conform to `CustomizableItem`. The cleanest place is in the existing model files, or in the settings view files themselves as extensions. Add them as extensions in each settings view file (so they stay local to the feature):

In `ActivitiesSettingsView.swift`, add before the struct:
```swift
extension SQLActivityTypeEntity: CustomizableItem {}
```

In `ProtectionMethodsSettingsView.swift`, add before the struct:
```swift
extension SQLProtectionMethodEntity: CustomizableItem {}
```

In `PositionsSettingsView.swift`, add before the struct:
```swift
extension SQLPositionType: CustomizableItem {}
```

In `PartnerAttributesSettingsView.swift`, add before the struct:
```swift
extension SQLPartnerAttributeType: CustomizableItem {}
```

**Note:** If any of these types already have `id`, `icon`, `name`, `isEnabled`, `isBuiltIn` as properties with the same types, the conformance is free. If any property is missing or has a different type, add a computed property in the extension. Verify by reading the model files before applying.

- [ ] **Step 3: Rewrite ActivitiesSettingsView to use CustomizationSettingsView**

Replace the entire `body` computed property of `ActivitiesSettingsView`:

```swift
var body: some View {
    CustomizationSettingsView(
        navigationTitle: "Activities",
        itemTypeName: "Activity",
        descriptionText: "Manage activities for logging encounters. Built-in activities can be enabled/disabled. Custom activities can be edited or deleted.",
        accentColor: accentColor,
        items: activities,
        onToggle: toggleActivity,
        onDelete: deleteActivity,
        addSheet: { ActivityFormView(onSave: loadActivities) },
        editSheet: { activity in ActivityFormView(activity: activity, onSave: loadActivities) },
        itemRow: { activity, toggle in
            ActivityRow(activity: activity, onToggle: toggle)
        }
    )
    .onAppear { loadActivities() }
}
```

- [ ] **Step 4: Rewrite ProtectionMethodsSettingsView to use CustomizationSettingsView**

```swift
var body: some View {
    CustomizationSettingsView(
        navigationTitle: "Protection Methods",
        itemTypeName: "Protection Method",
        descriptionText: "Manage protection methods for logging encounters. Built-in methods can be enabled/disabled. Custom methods can be edited or deleted.",
        accentColor: accentColor,
        items: protectionMethods,
        onToggle: toggleMethod,
        onDelete: deleteMethod,
        addSheet: { ProtectionMethodFormView(onSave: loadProtectionMethods) },
        editSheet: { method in ProtectionMethodFormView(method: method, onSave: loadProtectionMethods) },
        itemRow: { method, toggle in
            ProtectionMethodRow(method: method, onToggle: toggle)
        }
    )
    .onAppear { loadProtectionMethods() }
}
```

- [ ] **Step 5: Rewrite PositionsSettingsView to use CustomizationSettingsView**

```swift
var body: some View {
    CustomizationSettingsView(
        navigationTitle: "Positions",
        itemTypeName: "Position",
        descriptionText: "Manage positions for logging encounters. Built-in positions can be enabled/disabled. Custom positions can be edited or deleted.",
        accentColor: accentColor,
        items: positions,
        onToggle: toggle,
        onDelete: deletePosition,
        addSheet: { PositionFormView(onSave: load) },
        editSheet: { position in PositionFormView(position: position, onSave: load) },
        itemRow: { position, toggle in
            PositionRow(position: position, onToggle: toggle)
        }
    )
    .onAppear { load() }
}
```

Note: `PositionsSettingsView` has a secondary `showingDeleteError` alert for constraint errors. Keep it as an additional `.alert` modifier added to the result of `CustomizationSettingsView(...)` if needed, or handle it inside `deletePosition()` by setting a local `@State var deleteError`.

- [ ] **Step 6: Rewrite PartnerAttributesSettingsView to use CustomizationSettingsView**

```swift
var body: some View {
    CustomizationSettingsView(
        navigationTitle: "Partner Attributes",
        itemTypeName: "Attribute",
        descriptionText: "Manage custom fields for partner profiles. Built-in fields can be enabled/disabled. Custom fields can be edited or deleted.",
        accentColor: accentColor,
        items: attributes,
        onToggle: toggleAttribute,
        onDelete: deleteAttribute,
        addSheet: { PartnerAttributeFormView { loadAttributes() } },
        editSheet: { attribute in PartnerAttributeFormView(attribute: attribute) { loadAttributes() } },
        itemRow: { attribute, toggle in
            AttributeRow(attribute: attribute, onToggle: toggle)
        }
    )
    .task { loadAttributes() }
}
```

- [ ] **Step 7: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`. If there are protocol conformance errors, read the failing model type's definition and add the missing computed properties to the extension.

- [ ] **Step 8: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Settings/Customization/Components/CustomizationSettingsView.swift \
        Fuckify/Features/Settings/Customization/Activities/ActivitiesSettingsView.swift \
        Fuckify/Features/Settings/Customization/ProtectionMethods/ProtectionMethodsSettingsView.swift \
        Fuckify/Features/Settings/Customization/Positions/PositionsSettingsView.swift \
        Fuckify/Features/Settings/Customization/PartnerAttributes/PartnerAttributesSettingsView.swift
git commit -m "refactor: extract CustomizationSettingsView, consolidate 4 near-identical settings list views"
```

---

## Task 10: Consolidate Partner Chip Variants

There are 4 partner chip implementations:
1. `PartnerChip` (with remove button) — used in `EncounterFormView`
2. `EncounterDetailPartnerChip` (with position icon + heart) — used in `EncounterDetailView`
3. `PartnerDisplayChip` (with avatar circle) — used in `ActiveEncounterView`
4. `LiveActivityPartnerChipView` (compact vs standard) — used in `LiveActivityPartnerChipView.swift`

Strategy: Keep the existing `PartnerChip` name and file (callers don't need updating), but expand it to support all modes. Embed `PartnerAvatar` (from Task 2) for the display chip. Keep `LiveActivityPartnerChipView` separate since it serves a different host (Live Activity widget) with a different data type.

**Files:**
- Modify: `Fuckify/Features/Encounter/Components/PartnerChip.swift`
- Modify: `Fuckify/Features/Encounter/Views/EncounterDetailView.swift` (remove `EncounterDetailPartnerChip`)
- Modify: `Fuckify/Features/Encounter/Views/ActiveEncounterView.swift` (remove `PartnerDisplayChip`)

- [ ] **Step 1: Read EncounterDetailView.swift and ActiveEncounterView.swift**

Read both files to see the full `EncounterDetailPartnerChip` and `PartnerDisplayChip` implementations and all their call sites, so you can replicate behavior exactly.

- [ ] **Step 2: Expand PartnerChip.swift with a mode enum**

Replace the contents of `PartnerChip.swift`:

```swift
// Fuckify/Features/Encounter/Components/PartnerChip.swift

import SwiftUI
import SQLiteData

/// Unified partner chip for all encounter views.
enum PartnerChipMode {
    /// Removable chip used in encounter form. Shows partner name + xmark button.
    case removable(onRemove: () -> Void)

    /// Detail chip used in encounter detail view.
    /// Shows optional position icon on the left and optional orgasm heart on the right.
    case detail(positionIcon: String?, hadOrgasm: Bool)

    /// Display chip used in active encounter view.
    /// Shows a small avatar circle on the left.
    case display
}

struct PartnerChip: View {
    let partner: SQLPartner
    let mode: PartnerChipMode

    private var partnerColor: Color {
        Color.fromPartnerColorName(partner.avatarColor)
    }

    var body: some View {
        HStack(spacing: 6) {
            leadingContent
            nameText
            trailingContent
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(partnerColor.opacity(0.15))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leadingContent: some View {
        switch mode {
        case .display:
            PartnerAvatar(
                color: partnerColor,
                initials: partner.initials,
                size: 22
            )
        case .detail(let positionIcon, _):
            if let icon = positionIcon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(partnerColor)
            }
        case .removable:
            EmptyView()
        }
    }

    private var nameText: some View {
        Text(partner.name)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(1)
            .foregroundColor(partnerColor)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch mode {
        case .removable(let onRemove):
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(partnerColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(partner.name)")
            .accessibilityHint("Removes this partner from the encounter")

        case .detail(_, let hadOrgasm):
            if hadOrgasm {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(partnerColor)
            }

        case .display:
            EmptyView()
        }
    }
}

#Preview {
    let partner = SQLPartner.preview

    return VStack(spacing: 12) {
        PartnerChip(partner: partner, mode: .removable(onRemove: {}))
        PartnerChip(partner: partner, mode: .detail(positionIcon: "figure.stand", hadOrgasm: true))
        PartnerChip(partner: partner, mode: .detail(positionIcon: nil, hadOrgasm: false))
        PartnerChip(partner: partner, mode: .display)
    }
    .padding()
}
```

**Note:** This assumes `SQLPartner` has an `initials` property. If it doesn't (verify before applying), use `String(partner.name.prefix(2)).uppercased()` inline.

- [ ] **Step 3: Update the existing PartnerChip call sites in EncounterFormView.swift**

The existing `PartnerChip(partner:onRemove:)` initializer no longer exists. Update call sites in `EncounterFormView.swift`:

```swift
// BEFORE
PartnerChip(partner: partner, onRemove: { togglePartner(partner.id) })

// AFTER
PartnerChip(partner: partner, mode: .removable(onRemove: { togglePartner(partner.id) }))
```

- [ ] **Step 4: Replace EncounterDetailPartnerChip in EncounterDetailView.swift with PartnerChip**

Find every usage of `EncounterDetailPartnerChip(partner:positionIcon:hadOrgasm:)` and replace with:

```swift
PartnerChip(
    partner: partner,
    mode: .detail(positionIcon: <positionIcon>, hadOrgasm: <hadOrgasm>)
)
```

Then delete the `EncounterDetailPartnerChip` struct from `EncounterDetailView.swift`.

- [ ] **Step 5: Replace PartnerDisplayChip in ActiveEncounterView.swift with PartnerChip**

Find every usage of `PartnerDisplayChip(partner:)` and replace with:

```swift
PartnerChip(partner: <partner>, mode: .display)
```

Then delete the `PartnerDisplayChip` struct from `ActiveEncounterView.swift`.

**Note:** `PartnerDisplayChip` in `ActiveEncounterView` uses `PartnerData` not `SQLPartner`. Read the file to understand the data type — you may need to keep `PartnerDisplayChip` as a thin wrapper that converts `PartnerData` to display values, or extend `PartnerChip` to accept a protocol. If the types differ, keep `PartnerDisplayChip` but have it render `PartnerChip` internally with manually constructed values.

- [ ] **Step 6: Build and confirm**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`. If type errors arise from `PartnerData` vs `SQLPartner`, keep `PartnerDisplayChip` as a thin wrapper calling the new `PartnerChip` with `.display` mode and manually extracted values.

- [ ] **Step 7: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Encounter/Components/PartnerChip.swift \
        Fuckify/Features/Encounter/Views/EncounterDetailView.swift \
        Fuckify/Features/Encounter/Views/ActiveEncounterView.swift
git commit -m "refactor: consolidate partner chip variants into unified PartnerChip with mode enum"
```

---

## Final Verification

- [ ] **Build in Release mode**

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Release build \
  2>&1 | grep -E "(error:|BUILD)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Check for any leftover inline badge patterns**

```bash
cd /Users/zee/ws/spicy/Fuckify
grep -r 'Text("Built-in")' Fuckify/Features --include="*.swift" -l
```
Expected: no output (all replaced by `BuiltInBadge()`)

- [ ] **Check for any leftover inline avatar circle patterns**

```bash
grep -rn 'Circle().*fill.*frame' Fuckify/Features --include="*.swift" | grep -v "PartnerAvatar\|PINDots\|preview\|Preview"
```
Review remaining hits — they should be intentional non-partner uses.

- [ ] **Check for any leftover inline duration picker code**

```bash
grep -rn 'ForEach(0..<24)' Fuckify/Features --include="*.swift"
```
Expected: only one hit inside `DurationPickerSection.swift`.

- [ ] **Final commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add docs/superpowers/plans/2026-04-18-ui-component-consolidation.md
git commit -m "docs: add UI component consolidation implementation plan"
```

---

## Deferred Patterns (Post-Task-10 Implementation Plan)

These six patterns were intentionally deferred from the core plan. Execute them after Tasks 1-10 are stable.

### Deferred Task Order Overview

1. D5 Statistics section header (low-risk, local)
2. D3 STI summary rows (local + reused twice)
3. D1 Entity icon row (small reusable component)
4. D4 CSV import instructions view (shared UI extraction)
5. D6 Empty state view (cross-feature shared component)
6. D2 Partner attribute edit field (highest behavioral surface area)

---

## D1: Extract `EntityIconRow`

The same icon-chip row layout appears in encounters list rows and calendar rows.

**Files:**
- Create: `Fuckify/Features/Shared/Components/EntityIconRow.swift`
- Modify: `Fuckify/Features/Encounter/Views/EncountersListView.swift`
- Modify: `Fuckify/Features/Encounter/Views/CalendarEncounterRow.swift`

- [ ] **Step 1: Read both icon-row call sites and capture differences**

Read and compare the current inline icon-row implementations in:
- `EncounterRowView` in `EncountersListView.swift`
- `CalendarEncounterRow.swift`

Record:
- icon source type (activity entities vs protection entities)
- color per row
- max displayed icons and overflow behavior
- spacing/font/frame differences

- [ ] **Step 2: Create `EntityIconRow.swift`**

Add a reusable row component:

```swift
import SwiftUI

struct EntityIconRow: View {
    let entities: [(icon: String, name: String)]
    let color: Color
    var maxShown: Int = 3
    var font: Font = .caption

    private var shownEntities: ArraySlice<(icon: String, name: String)> {
        entities.prefix(maxShown)
    }

    private var remainingCount: Int {
        max(0, entities.count - maxShown)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(shownEntities.enumerated()), id: \.offset) { _, entity in
                Image(systemName: entity.icon)
                    .font(font)
                    .foregroundColor(color)
                    .accessibilityLabel(entity.name)
            }

            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(font)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

- [ ] **Step 3: Replace inline icon rows in both call sites**

Convert each call site to pass:
- `entities: [(icon, name)]`
- row-specific `color`
- row-specific `maxShown` (if different)
- row-specific `font` (if different)

- [ ] **Step 4: Build and verify**

Run:

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Shared/Components/EntityIconRow.swift \
        Fuckify/Features/Encounter/Views/EncountersListView.swift \
        Fuckify/Features/Encounter/Views/CalendarEncounterRow.swift
git commit -m "refactor: extract EntityIconRow and replace duplicated activity/protection icon rows"
```

---

## D2: Extract `PartnerAttributeEditField`

Partner attribute form field rendering is duplicated across partner create/edit and detail-edit flows.

**Files:**
- Create: `Fuckify/Features/Partner/Components/PartnerAttributeEditField.swift`
- Modify: `Fuckify/Features/Partner/Views/PartnerFormView.swift`
- Modify: `Fuckify/Features/Partner/Views/PartnerDetailView.swift`

- [ ] **Step 1: Read both field-rendering functions in full**

Read:
- `customAttributeField(for:)` in `PartnerFormView.swift`
- `customAttributeEditField(for:)` in `PartnerDetailView.swift`

Capture behavior by field type (`text`, `boolean`, `date`, `enum`) and null/empty handling.

- [ ] **Step 2: Create `PartnerAttributeEditField.swift`**

Implement:

```swift
import SwiftUI

struct PartnerAttributeEditField: View {
    let attribute: SQLPartnerAttributeType
    @Binding var value: String?

    var body: some View {
        switch attribute.parsedFieldType {
        case .text:
            TextField(attribute.name, text: Binding(
                get: { value ?? "" },
                set: { value = $0.isEmpty ? nil : $0 }
            ))
        case .boolean:
            Toggle(attribute.name, isOn: Binding(
                get: { (value ?? "false") == "true" },
                set: { value = $0 ? "true" : "false" }
            ))
        case .date:
            DatePicker(
                attribute.name,
                selection: Binding(
                    get: { ISO8601DateFormatter().date(from: value ?? "") ?? Date() },
                    set: { value = ISO8601DateFormatter().string(from: $0) }
                ),
                displayedComponents: .date
            )
        case .enumType:
            Picker(attribute.name, selection: Binding(
                get: { value ?? "" },
                set: { value = $0.isEmpty ? nil : $0 }
            )) {
                Text("Not set").tag("")
                ForEach(attribute.parsedEnumChoices, id: \.self) { choice in
                    Text(choice).tag(choice)
                }
            }
        }
    }
}
```

Adjust details to match exact existing behavior if the live code differs.

- [ ] **Step 3: Replace duplicated switch blocks in both views**

At each call site, replace inline switch rendering with:

```swift
PartnerAttributeEditField(attribute: attribute, value: <binding>)
```

Ensure the existing backing storage type (`[UUID: String?]`, etc.) remains unchanged.

- [ ] **Step 4: Build and verify**

Run the same Debug build command; expected `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Partner/Components/PartnerAttributeEditField.swift \
        Fuckify/Features/Partner/Views/PartnerFormView.swift \
        Fuckify/Features/Partner/Views/PartnerDetailView.swift
git commit -m "refactor: extract PartnerAttributeEditField and remove duplicated attribute field rendering"
```

---

## D3: Extract `STISummaryRows`

STI summary row content is duplicated between profile card and STI history header.

**Files:**
- Create: `Fuckify/Features/STI/Components/STISummaryRows.swift`
- Modify: `Fuckify/Features/Profile/ProfileView.swift`
- Modify: `Fuckify/Features/STI/Views/STIHistoryView.swift`

- [ ] **Step 1: Read existing STI summary content in both files**

Read:
- `STITestingCard` in `ProfileView.swift`
- `summaryHeaderSection` in `STIHistoryView.swift`

Identify exactly which rows should move (last test date + next recommended test date + status text).

- [ ] **Step 2: Create `STISummaryRows.swift`**

Create a rows-only component that does not own outer container styling:

```swift
import SwiftUI

struct STISummaryRows: View {
    let manager: STIManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Move only the repeated row content here
        }
    }
}
```

- [ ] **Step 3: Replace duplicated rows in both hosts**

Use:

```swift
STISummaryRows(manager: stiManager)
```

Keep host-specific wrapper behavior:
- Profile card keeps its card style / NavigationLink behavior
- STI history keeps its own section container and navigation context

- [ ] **Step 4: Build and verify**

Run Debug build; expected `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/STI/Components/STISummaryRows.swift \
        Fuckify/Features/Profile/ProfileView.swift \
        Fuckify/Features/STI/Views/STIHistoryView.swift
git commit -m "refactor: extract STISummaryRows and reuse STI summary content across profile and history"
```

---

## D4: Extract `CSVImportInstructionsView`

Partner and encounter import screens duplicate CSV instructions and “select file” action UI.

**Files:**
- Create: `Fuckify/Features/Settings/DataManagement/CSVImportInstructionsView.swift`
- Modify: `Fuckify/Features/Settings/DataManagement/PartnerImportView.swift`
- Modify: `Fuckify/Features/Settings/DataManagement/EncounterImportView.swift`

- [ ] **Step 1: Read both import instruction sections**

Read instruction blocks from both files and note differences in wording/examples.

- [ ] **Step 2: Create `CSVImportInstructionsView.swift`**

Add a configurable shared component:

```swift
import SwiftUI

struct CSVImportInstructionsView: View {
    let title: String
    let color: Color
    let format: String
    let example: String
    let notes: String
    let onSelectFile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title, format text, monospaced example block, notes, and select-file button
        }
    }
}
```

- [ ] **Step 3: Replace duplicated instruction UI in both import screens**

Supply file-specific strings and preserve each screen’s parsing/import logic unchanged.

- [ ] **Step 4: Build and verify**

Run Debug build; expected `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Settings/DataManagement/CSVImportInstructionsView.swift \
        Fuckify/Features/Settings/DataManagement/PartnerImportView.swift \
        Fuckify/Features/Settings/DataManagement/EncounterImportView.swift
git commit -m "refactor: extract CSVImportInstructionsView and remove duplicated import instructions"
```

---

## D5: Extract `StatSectionContainer` (private helper)

Statistics section headers repeat identical `VStack + title` scaffolding.

**Files:**
- Modify: `Fuckify/Features/Statistics/Views/StatisticsView.swift`

- [ ] **Step 1: Identify all duplicated statistics section containers**

Read all section views in `StatisticsView.swift` and list the repeated title/header wrapper blocks.

- [ ] **Step 2: Add private helper at bottom of file**

```swift
private struct StatSectionContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            content()
        }
    }
}
```

- [ ] **Step 3: Replace 5 repeated wrappers with `StatSectionContainer`**

Wrap existing inner content without changing metrics calculations or row/card styles.

- [ ] **Step 4: Build and verify**

Run Debug build; expected `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Statistics/Views/StatisticsView.swift
git commit -m "refactor: add StatSectionContainer helper to reduce repeated statistics section scaffolding"
```

---

## D6: Extract `EmptyStateView`

Three custom empty-state VStacks duplicate icon/title/description/action layout patterns.

**Files:**
- Create: `Fuckify/Features/Shared/Components/EmptyStateView.swift`
- Modify: `Fuckify/Features/STI/Views/STIHistoryView.swift`
- Modify: `Fuckify/Features/Profile/ProfileView.swift`
- Modify: `Fuckify/Features/Statistics/Views/StatisticsView.swift`

- [ ] **Step 1: Read all three custom empty-state implementations**

Confirm exact copy and host-specific differences.

- [ ] **Step 2: Create `EmptyStateView.swift`**

```swift
import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let actionLabel: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(iconColor)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 3: Replace only the three custom VStacks**

Keep existing `ContentUnavailableView` usages unchanged.

- [ ] **Step 4: Build and verify**

Run Debug build; expected `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd /Users/zee/ws/spicy/Fuckify
git add Fuckify/Features/Shared/Components/EmptyStateView.swift \
        Fuckify/Features/STI/Views/STIHistoryView.swift \
        Fuckify/Features/Profile/ProfileView.swift \
        Fuckify/Features/Statistics/Views/StatisticsView.swift
git commit -m "refactor: extract EmptyStateView and replace duplicated custom empty-state layouts"
```

---

## Deferred Final Verification

- [ ] Run full Debug build

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Debug build \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Run full Release build

```bash
xcodebuild -project /Users/zee/ws/spicy/Fuckify/Fuckify.xcodeproj \
  -scheme Fuckify -configuration Release build \
  2>&1 | grep -E "(error:|BUILD)"
```

Expected: `BUILD SUCCEEDED`

- [ ] Optional sanity grep checks

```bash
cd /Users/zee/ws/spicy/Fuckify
grep -rn "customAttributeField(for:)\|customAttributeEditField(for:)" Fuckify --include="*.swift"
grep -rn "No Data Yet\|Track Your STI Tests" Fuckify --include="*.swift"
```

Expected: only component definitions and intended call sites remain.
