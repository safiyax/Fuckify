# Feature Flags Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the PostHog-based feature flag system with a custom API-backed implementation using `FeatureFlagsService` + `FeatureFlagsProvider`, remove all PostHog dependencies, and update the debug menu to mirror the flag dot-path hierarchy.

**Architecture:** A background `actor` (`FeatureFlagsService`) fetches flags from the custom API and caches them in UserDefaults. An `@Observable @MainActor` class (`FeatureFlagsProvider`) owns the live flag dictionary plus DEBUG-only overrides, and exposes domain-specific computed property structs (`featureFlags.settings.showAppIconPicker`). It is injected via `@Environment` from `FuckifyApp`, matching the pattern of `securitySettings` and `userSettings`.

**Tech Stack:** Swift, SwiftUI, URLSession, `@Observable` (iOS 17+), `actor`, UserDefaults, `#if DEBUG`

---

## File Map

### Created
- `Fuckify/Features/FeatureFlags/FeatureFlagsService.swift` — `actor` for networking + UserDefaults cache
- `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift` — private `FeatureFlagKey` enum + `@Observable` provider + all computed property structs

### Rewritten
- `Fuckify/Features/Settings/Debug/DebugMenuView.swift` — unified flag list organized by dot-path sections
- `Fuckify/Features/Settings/Debug/DebugFlagRow.swift` — adds override indicator

### Updated (consumer views)
- `Fuckify/FuckifyApp.swift` — remove PostHog, add `featureFlags` state + environment
- `Fuckify/Features/Settings/Views/SettingsView.swift` — use `@Environment(FeatureFlagsProvider.self)`
- `Fuckify/Features/Settings/DataManagement/ImportView.swift` — use `@Environment(FeatureFlagsProvider.self)`

### Deleted
- `Fuckify/Features/Settings/Managers/FeatureFlagsManager.swift`
- `Fuckify/Features/Settings/Config/SettingsConfig.swift`
- `Fuckify/Features/Settings/DataManagement/Config/ImportExportConfig.swift`
- `Fuckify/Features/Settings/Debug/SettingsFlagsDetailView.swift`
- `Fuckify/Features/Settings/Debug/ImportExportFlagsDetailView.swift`
- `Fuckify/Features/Settings/Debug/DebugMenuFlagDetailView.swift`

---

## Task 1: Create `FeatureFlagsService`

**Files:**
- Create: `Fuckify/Features/FeatureFlags/FeatureFlagsService.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  FeatureFlagsService.swift
//  Fuckify
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "FeatureFlags")

actor FeatureFlagsService {
    private let cacheKey = "feature_flags_cache"
    private let cacheTimestampKey = "feature_flags_cache_timestamp"
    private let baseURL = "https://dev.coitalcomra.de/api/feature-flags"

    // MARK: - Network

    func fetchFlags() async throws -> [String: Bool] {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "build", value: build),
            URLQueryItem(name: "platform", value: "ios")
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            logger.warning("Feature flags API returned status \(code)")
            throw FeatureFlagsError.badResponse(code)
        }

        let flags = try JSONDecoder().decode([String: Bool].self, from: data)
        logger.info("Fetched \(flags.count) feature flags (version: \(version), build: \(build))")
        return flags
    }

    // MARK: - Cache

    func cachedFlags() -> [String: Bool] {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let flags = try? JSONDecoder().decode([String: Bool].self, from: data) else {
            return [:]
        }
        return flags
    }

    func persistFlags(_ flags: [String: Bool]) {
        guard let data = try? JSONEncoder().encode(flags) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
        UserDefaults.standard.set(Date(), forKey: cacheTimestampKey)
        logger.debug("Persisted \(flags.count) flags to cache")
    }

    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: cacheTimestampKey)
        logger.info("Feature flags cache cleared")
    }

    func lastFetchedDate() -> Date? {
        UserDefaults.standard.object(forKey: cacheTimestampKey) as? Date
    }
}

// MARK: - Errors

enum FeatureFlagsError: Error {
    case badResponse(Int)
}
```

- [ ] **Step 2: Build the project to check for compile errors**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: No new errors related to `FeatureFlagsService`.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/FeatureFlags/FeatureFlagsService.swift
git commit -m "feat: add FeatureFlagsService actor for API fetch and cache"
```

---

## Task 2: Create `FeatureFlagsProvider`

**Files:**
- Create: `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift`

- [ ] **Step 1: Create the file**

```swift
//
//  FeatureFlagsProvider.swift
//  Fuckify
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "FeatureFlags")

// MARK: - Internal Key Enum (not exposed to views)

private enum FeatureFlagKey: String {
    // settings.personalization
    case settingsPersonalizationAppIconPicker         = "settings.personalization.appIconPicker"
    case settingsPersonalizationActivities            = "settings.personalization.activities"
    case settingsPersonalizationProtectionMethods     = "settings.personalization.protectionMethods"
    case settingsPersonalizationPositions             = "settings.personalization.positions"
    case settingsPersonalizationSecurity              = "settings.personalization.security"
    case settingsPersonalizationAppIconPickerSpicyIcons = "settings.personalization.appIconPicker.spicyIcons"

    // settings.data
    case settingsDataImportExport                     = "settings.data.importExport"
    case settingsDataDeleteData                       = "settings.data.deleteData"

    // settings.data.importExport
    case settingsDataImportExportCsvImportPartners    = "settings.data.importExport.csvImportPartners"
    case settingsDataImportExportCsvImportEncounters  = "settings.data.importExport.csvImportEncounters"
    case settingsDataImportExportCsvExportPartners    = "settings.data.importExport.csvExportPartners"
    case settingsDataImportExportCsvExportEncounters  = "settings.data.importExport.csvExportEncounters"
    case settingsDataImportExportImportDatabase       = "settings.data.importExport.importDatabase"
    case settingsDataImportExportExportDatabase       = "settings.data.importExport.exportDatabase"

    // settings.more
    case settingsMoreAbout                            = "settings.more.about"
    case settingsMoreSupportApp                       = "settings.more.supportApp"
    case settingsMoreExperiments                      = "settings.more.experiments"
    case settingsMoreDebugMenu                        = "settings.more.debugMenu"
}

// MARK: - Provider

@Observable
@MainActor
final class FeatureFlagsProvider {
    private(set) var flags: [String: Bool] = [:]
    private(set) var isLoaded: Bool = false

    #if DEBUG
    private(set) var overrides: [String: Bool] = [:]
    private let overridesKey = "feature_flags_overrides"
    #endif

    private let service = FeatureFlagsService()

    // MARK: - Lifecycle

    func load() async {
        // 1. Load from cache immediately
        let cached = await service.cachedFlags()
        flags = cached
        isLoaded = true
        logger.debug("Loaded \(cached.count) flags from cache")

        #if DEBUG
        loadOverrides()
        #endif

        // 2. Fetch fresh in background
        do {
            let fresh = try await service.fetchFlags()
            flags = fresh
            await service.persistFlags(fresh)
        } catch {
            logger.warning("Failed to fetch fresh flags, using cache: \(error)")
        }
    }

    // MARK: - Flag Resolution

    func isEnabled(_ key: FeatureFlagKey) -> Bool {
        #if DEBUG
        if let override = overrides[key.rawValue] {
            return override
        }
        #endif
        return flags[key.rawValue] ?? false
    }

    // MARK: - Debug Overrides

    #if DEBUG
    func setOverride(_ key: FeatureFlagKey, value: Bool?) {
        if let value {
            overrides[key.rawValue] = value
        } else {
            overrides.removeValue(forKey: key.rawValue)
        }
        persistOverrides()
    }

    func clearAllOverrides() {
        overrides = [:]
        UserDefaults.standard.removeObject(forKey: overridesKey)
        logger.info("All feature flag overrides cleared")
    }

    func forceRefresh() async {
        do {
            let fresh = try await service.fetchFlags()
            flags = fresh
            await service.persistFlags(fresh)
            logger.info("Force refreshed \(fresh.count) flags")
        } catch {
            logger.warning("Force refresh failed: \(error)")
        }
    }

    func clearFlagCache() async {
        await service.clearCache()
    }

    func lastFetchedDate() async -> Date? {
        await service.lastFetchedDate()
    }

    private func loadOverrides() {
        guard let data = UserDefaults.standard.data(forKey: overridesKey),
              let saved = try? JSONDecoder().decode([String: Bool].self, from: data) else { return }
        overrides = saved
        logger.debug("Loaded \(saved.count) flag overrides")
    }

    private func persistOverrides() {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: overridesKey)
    }
    #endif

    // MARK: - Domain Views

    var settings: SettingsFlags { SettingsFlags(provider: self) }
}

// MARK: - SettingsFlags

struct SettingsFlags {
    let provider: FeatureFlagsProvider

    var showAppIconPicker: Bool    { provider.isEnabled(.settingsPersonalizationAppIconPicker) }
    var showActivities: Bool       { provider.isEnabled(.settingsPersonalizationActivities) }
    var showProtectionMethods: Bool { provider.isEnabled(.settingsPersonalizationProtectionMethods) }
    var showPositions: Bool        { provider.isEnabled(.settingsPersonalizationPositions) }
    var showSecurity: Bool         { provider.isEnabled(.settingsPersonalizationSecurity) }

    var appIconPicker: AppIconPickerFlags { AppIconPickerFlags(provider: provider) }
    var data: SettingsDataFlags           { SettingsDataFlags(provider: provider) }
    var more: SettingsMoreFlags           { SettingsMoreFlags(provider: provider) }

    // Section-level helpers
    var showPersonalizationSection: Bool {
        showAppIconPicker || showActivities || showProtectionMethods || showPositions || showSecurity
    }
    var showDataSection: Bool { data.showImportExport || data.showDeleteData }
    var showMoreSection: Bool { more.showAbout || more.showSupportApp || more.showExperiments }
}

// MARK: - AppIconPickerFlags

struct AppIconPickerFlags {
    let provider: FeatureFlagsProvider
    var showSpicyIcons: Bool { provider.isEnabled(.settingsPersonalizationAppIconPickerSpicyIcons) }
}

// MARK: - SettingsDataFlags

struct SettingsDataFlags {
    let provider: FeatureFlagsProvider
    var showImportExport: Bool { provider.isEnabled(.settingsDataImportExport) }
    var showDeleteData: Bool   { provider.isEnabled(.settingsDataDeleteData) }
    var importExport: ImportExportFlags { ImportExportFlags(provider: provider) }
}

// MARK: - ImportExportFlags

struct ImportExportFlags {
    let provider: FeatureFlagsProvider
    var showCsvImportPartners: Bool   { provider.isEnabled(.settingsDataImportExportCsvImportPartners) }
    var showCsvImportEncounters: Bool { provider.isEnabled(.settingsDataImportExportCsvImportEncounters) }
    var showCsvExportPartners: Bool   { provider.isEnabled(.settingsDataImportExportCsvExportPartners) }
    var showCsvExportEncounters: Bool { provider.isEnabled(.settingsDataImportExportCsvExportEncounters) }
    var showImportDatabase: Bool      { provider.isEnabled(.settingsDataImportExportImportDatabase) }
    var showExportDatabase: Bool      { provider.isEnabled(.settingsDataImportExportExportDatabase) }

    // Section-level helpers (used by ImportView)
    var showImportCSVSection: Bool { showCsvImportPartners || showCsvImportEncounters }
    var showExportCSVSection: Bool { showCsvExportPartners || showCsvExportEncounters }
}

// MARK: - SettingsMoreFlags

struct SettingsMoreFlags {
    let provider: FeatureFlagsProvider
    var showAbout: Bool       { provider.isEnabled(.settingsMoreAbout) }
    var showSupportApp: Bool  { provider.isEnabled(.settingsMoreSupportApp) }
    var showExperiments: Bool { provider.isEnabled(.settingsMoreExperiments) }
    var showDebugMenu: Bool   { provider.isEnabled(.settingsMoreDebugMenu) }
}
```

- [ ] **Step 2: Build the project**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: No errors from the new files.

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift
git commit -m "feat: add FeatureFlagsProvider with typed domain views"
```

---

## Task 3: Update `FuckifyApp` — add provider, remove PostHog

**Files:**
- Modify: `Fuckify/FuckifyApp.swift`

- [ ] **Step 1: Remove the PostHog import and setup block**

Remove line 12:
```swift
import PostHog
```

Remove lines 116–135 from `init()` (the entire PostHog config block):
```swift
let POSTHOG_API_KEY = "phc_3B4gzM4mmgBj8lOIT6cKjQIqdFF3Dwnsca2ekWF0FYV"
// ... through ...
PostHogSDK.shared.setPersonPropertiesForFlags(properties, reloadFeatureFlags: true)
```

- [ ] **Step 2: Add `featureFlags` state and wire into the environment**

Add alongside the other `@State` managers at the top of `FuckifyApp`:
```swift
@State private var featureFlags = FeatureFlagsProvider()
```

In the `WindowGroup` body, add `.environment(featureFlags)` and `.task { await featureFlags.load() }` to the `ContentView()` call. The full modifier chain becomes:

```swift
ContentView()
    .environment(securitySettings)
    .environment(userProfile)
    .environment(userSettings)
    .environment(liveActivityManager)
    .environment(stiManager)
    .environment(featureFlags)
    .environment(\.appIsLocked, securitySettings.isSecurityEnabled && !isUnlocked)
    .task {
        await stiManager.load()
        await featureFlags.load()
    }
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: No PostHog-related errors. There will still be errors from files that reference `SettingsConfig.shared` — those are fixed in subsequent tasks.

- [ ] **Step 4: Commit**

```bash
git add Fuckify/FuckifyApp.swift
git commit -m "feat: inject FeatureFlagsProvider, remove PostHog setup"
```

---

## Task 4: Update `SettingsView`

**Files:**
- Modify: `Fuckify/Features/Settings/Views/SettingsView.swift`

- [ ] **Step 1: Replace `@State private var config = SettingsConfig.shared` with environment**

Remove:
```swift
@State private var config = SettingsConfig.shared
```

Add:
```swift
@Environment(FeatureFlagsProvider.self) private var featureFlags
```

- [ ] **Step 2: Replace all `config.` references**

| Old | New |
|-----|-----|
| `config.showPersonalizationSection` | `featureFlags.settings.showPersonalizationSection` |
| `config.showAppIconPicker` | `featureFlags.settings.showAppIconPicker` |
| `config.showActivities` | `featureFlags.settings.showActivities` |
| `config.showProtectionMethods` | `featureFlags.settings.showProtectionMethods` |
| `config.showPositions` | `featureFlags.settings.showPositions` |
| `config.showSecurity` | `featureFlags.settings.showSecurity` |
| `config.showDataSection` | `featureFlags.settings.showDataSection` |
| `config.showImportExport` | `featureFlags.settings.data.showImportExport` |
| `config.showDeleteData` | `featureFlags.settings.data.showDeleteData` |
| `config.showMoreSection` | `featureFlags.settings.showMoreSection` |
| `config.showAbout` | `featureFlags.settings.more.showAbout` |
| `config.showSupport` | `featureFlags.settings.more.showSupportApp` |
| `config.showExperiments` | `featureFlags.settings.more.showExperiments` |
| `config.showDebugMenu` | `featureFlags.settings.more.showDebugMenu` |

- [ ] **Step 3: Build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `SettingsView.swift` compiles cleanly.

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Features/Settings/Views/SettingsView.swift
git commit -m "feat: update SettingsView to use FeatureFlagsProvider"
```

---

## Task 5: Update `ImportView`

**Files:**
- Modify: `Fuckify/Features/Settings/DataManagement/ImportView.swift`

- [ ] **Step 1: Replace `ImportExportConfig.shared` with environment**

Remove line 26:
```swift
private let config = ImportExportConfig.shared
```

Add after the existing `@Environment(\.dismiss)` line:
```swift
@Environment(FeatureFlagsProvider.self) private var featureFlags
```

- [ ] **Step 2: Replace all `config.` references**

| Old | New |
|-----|-----|
| `config.showImportCSVSection` | `featureFlags.settings.data.importExport.showImportCSVSection` |
| `config.showExportCSVSection` | `featureFlags.settings.data.importExport.showExportCSVSection` |

Note: The "Advanced" database section (Import/Export Database buttons) in `ImportView` is currently shown unconditionally. Leave it unconditional — the spec does not require gating it via flags in this view. Only the CSV sections are flag-gated.

- [ ] **Step 3: Build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `ImportView.swift` compiles cleanly.

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Features/Settings/DataManagement/ImportView.swift
git commit -m "feat: update ImportView to use FeatureFlagsProvider"
```

---

## Task 6: Rewrite `DebugFlagRow`

**Files:**
- Modify: `Fuckify/Features/Settings/Debug/DebugFlagRow.swift`

- [ ] **Step 1: Rewrite the file**

The row now accepts an optional `isOverridden` flag. When `true`, shows an orange dot badge on the icon to signal that the current value is a local override rather than the API value.

```swift
//
//  DebugFlagRow.swift
//  Fuckify
//
//  Reusable row for feature flag toggles in the debug menu.
//  Shows an orange indicator when the value is a local override.
//

import SwiftUI

struct DebugFlagRow: View {
    let label: String
    @Binding var value: Bool
    var isOverridden: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(value ? .green : .red)
                    .font(.body)

                if isOverridden {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }

            Text(label)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Toggle("", isOn: $value)
                .labelsHidden()
        }
    }
}
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 3: Commit**

```bash
git add Fuckify/Features/Settings/Debug/DebugFlagRow.swift
git commit -m "feat: update DebugFlagRow with override indicator"
```

---

## Task 7: Rewrite `DebugMenuView`

**Files:**
- Modify: `Fuckify/Features/Settings/Debug/DebugMenuView.swift`

- [ ] **Step 1: Rewrite the file**

The new view is flat — all flags inline, no drill-down. Sections are named after their dot-path prefix. Each toggle calls `featureFlags.setOverride(_:value:)` directly. The `isOverridden` parameter on `DebugFlagRow` is set by comparing the current resolved value against the raw API value (i.e. whether `overrides[key]` exists).

```swift
//
//  DebugMenuView.swift
//  Fuckify
//
//  Debug menu — only visible when settings.more.debugMenu flag is enabled.
//  Flags are organized by their dot-path hierarchy.
//  Local overrides persist across launches (DEBUG builds only).
//

import SwiftUI

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @State private var isRefreshing = false
    @State private var lastFetched: Date? = nil

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Info
                Section {
                    Text("Toggles here set **local overrides** that take precedence over API values. Orange dot = override active. Overrides persist across launches.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: Actions
                Section("Actions") {
                    Button {
                        Task {
                            isRefreshing = true
                            await featureFlags.forceRefresh()
                            lastFetched = await featureFlags.lastFetchedDate()
                            isRefreshing = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reload Flags Now")
                            Spacer()
                            if isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(isRefreshing)

                    Button(role: .destructive) {
                        featureFlags.clearAllOverrides()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Clear All Overrides")
                        }
                    }
                }

                // MARK: settings.personalization
                Section("settings.personalization") {
                    flagRow("appIconPicker",
                            key: "settings.personalization.appIconPicker",
                            current: featureFlags.settings.showAppIconPicker)
                    flagRow("activities",
                            key: "settings.personalization.activities",
                            current: featureFlags.settings.showActivities)
                    flagRow("protectionMethods",
                            key: "settings.personalization.protectionMethods",
                            current: featureFlags.settings.showProtectionMethods)
                    flagRow("positions",
                            key: "settings.personalization.positions",
                            current: featureFlags.settings.showPositions)
                    flagRow("security",
                            key: "settings.personalization.security",
                            current: featureFlags.settings.showSecurity)
                    flagRow("  appIconPicker.spicyIcons",
                            key: "settings.personalization.appIconPicker.spicyIcons",
                            current: featureFlags.settings.appIconPicker.showSpicyIcons)
                }

                // MARK: settings.data
                Section("settings.data") {
                    flagRow("importExport",
                            key: "settings.data.importExport",
                            current: featureFlags.settings.data.showImportExport)
                    flagRow("deleteData",
                            key: "settings.data.deleteData",
                            current: featureFlags.settings.data.showDeleteData)
                    flagRow("  importExport.csvImportPartners",
                            key: "settings.data.importExport.csvImportPartners",
                            current: featureFlags.settings.data.importExport.showCsvImportPartners)
                    flagRow("  importExport.csvImportEncounters",
                            key: "settings.data.importExport.csvImportEncounters",
                            current: featureFlags.settings.data.importExport.showCsvImportEncounters)
                    flagRow("  importExport.csvExportPartners",
                            key: "settings.data.importExport.csvExportPartners",
                            current: featureFlags.settings.data.importExport.showCsvExportPartners)
                    flagRow("  importExport.csvExportEncounters",
                            key: "settings.data.importExport.csvExportEncounters",
                            current: featureFlags.settings.data.importExport.showCsvExportEncounters)
                    flagRow("  importExport.importDatabase",
                            key: "settings.data.importExport.importDatabase",
                            current: featureFlags.settings.data.importExport.showImportDatabase)
                    flagRow("  importExport.exportDatabase",
                            key: "settings.data.importExport.exportDatabase",
                            current: featureFlags.settings.data.importExport.showExportDatabase)
                }

                // MARK: settings.more
                Section("settings.more") {
                    flagRow("about",
                            key: "settings.more.about",
                            current: featureFlags.settings.more.showAbout)
                    flagRow("supportApp",
                            key: "settings.more.supportApp",
                            current: featureFlags.settings.more.showSupportApp)
                    flagRow("experiments",
                            key: "settings.more.experiments",
                            current: featureFlags.settings.more.showExperiments)
                    flagRow("debugMenu",
                            key: "settings.more.debugMenu",
                            current: featureFlags.settings.more.showDebugMenu)
                }

                // MARK: App Info
                Section("App Info") {
                    LabeledContent("Version", value: appVersion())
                    LabeledContent("Last Fetched", value: lastFetched.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                    Button(role: .destructive) {
                        Task { await featureFlags.clearFlagCache() }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Flag Cache")
                        }
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
            .task {
                lastFetched = await featureFlags.lastFetchedDate()
            }
        }
    }

    // MARK: - Helpers

    private func flagRow(_ label: String, key: String, current: Bool) -> some View {
        let isOverridden = featureFlags.overrides[key] != nil
        let binding = Binding<Bool>(
            get: { current },
            set: { newValue in featureFlags.setOverrideRaw(key, value: newValue) }
        )
        return DebugFlagRow(label: label, value: binding, isOverridden: isOverridden)
    }

    private func appVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    DebugMenuView()
        .environment(FeatureFlagsProvider())
}
```

- [ ] **Step 2: Add raw-string override helper to `FeatureFlagsProvider`**

The `flagRow` helper above calls `featureFlags.setOverrideRaw(_:value:)` directly by string key. Add this to `FeatureFlagsProvider.swift` inside the `#if DEBUG` block:

```swift
#if DEBUG
// Called by DebugMenuView which works with raw key strings directly
func setOverrideRaw(_ rawKey: String, value: Bool) {
    overrides[rawKey] = value
    persistOverrides()
}
#endif
```

- [ ] **Step 3: Build**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Fuckify/Features/Settings/Debug/DebugMenuView.swift Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift
git commit -m "feat: rewrite DebugMenuView with flat flag hierarchy and overrides"
```

---

## Task 8: Delete old files

**Files deleted:**
- `Fuckify/Features/Settings/Managers/FeatureFlagsManager.swift`
- `Fuckify/Features/Settings/Config/SettingsConfig.swift`
- `Fuckify/Features/Settings/DataManagement/Config/ImportExportConfig.swift`
- `Fuckify/Features/Settings/Debug/SettingsFlagsDetailView.swift`
- `Fuckify/Features/Settings/Debug/ImportExportFlagsDetailView.swift`
- `Fuckify/Features/Settings/Debug/DebugMenuFlagDetailView.swift`

- [ ] **Step 1: Delete the files from disk**

```bash
rm Fuckify/Features/Settings/Managers/FeatureFlagsManager.swift
rm Fuckify/Features/Settings/Config/SettingsConfig.swift
rm Fuckify/Features/Settings/DataManagement/Config/ImportExportConfig.swift
rm Fuckify/Features/Settings/Debug/SettingsFlagsDetailView.swift
rm Fuckify/Features/Settings/Debug/ImportExportFlagsDetailView.swift
rm Fuckify/Features/Settings/Debug/DebugMenuFlagDetailView.swift
```

- [ ] **Step 2: Remove the files from the Xcode project**

Open `Fuckify.xcodeproj` in Xcode. In the Project Navigator, select each deleted file (they will show as red/missing) and press Delete → "Remove Reference". Alternatively, edit `project.pbxproj` to remove their entries — but using Xcode is safer.

- [ ] **Step 3: Remove the PostHog Swift Package**

In Xcode: Project → Package Dependencies → select PostHog → click the minus (`-`) button → confirm removal. Note: `import PostHog` has already been removed from `FuckifyApp.swift` (Task 3) and `DebugMenuView.swift` (Task 7). Removing the package here just eliminates the SPM dependency itself.

- [ ] **Step 4: Build and confirm clean**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug build 2>&1 | grep -E "error:|Build succeeded"
```

Expected: `Build succeeded` with no errors.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove PostHog and old feature flag infrastructure"
```

---

## Task 9: Smoke test

- [ ] **Step 1: Run on simulator**

```bash
xcodebuild -project Fuckify.xcodeproj -scheme Fuckify -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build 2>&1 | grep -E "error:|Build succeeded"
```

- [ ] **Step 2: Manual verification checklist**

Launch the app on simulator and verify:

1. **Settings screen loads** — no crash, sections appear (some may be hidden depending on API response)
2. **Debug menu visible** — shake or check if `settings.more.debugMenu` returns `true` from API; if not, temporarily set it via UserDefaults:
   ```swift
   // In Xcode console or via lldb:
   // po UserDefaults.standard.setValue(Data(#"{"settings.more.debugMenu":true}"#.utf8), forKey: "feature_flags_cache")
   ```
3. **Debug menu toggles work** — toggling a flag shows the orange override dot, the setting takes effect immediately in the UI (e.g. toggle `settings.personalization.activities` off → go back to Settings → Activities row is gone)
4. **Clear All Overrides** — clears dots, values return to API state
5. **Force Reload** — spinner appears, flags refresh from API
6. **No PostHog references** — search project for `PostHog` and confirm zero results

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
git add -A
git commit -m "fix: smoke test fixes"
```
