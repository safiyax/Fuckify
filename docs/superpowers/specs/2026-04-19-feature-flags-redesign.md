# Feature Flags Redesign

**Date:** 2026-04-19  
**Status:** Approved

## Overview

Replace the PostHog-based feature flag implementation with a custom API-backed system. Remove all PostHog dependencies. The new system is simpler, uses no third-party SDK, and fits the existing `@Observable` + `@Environment` patterns already used throughout the app.

## Goals

- Fetch boolean flags from `https://dev.coitalcomra.de/api/feature-flags`
- Remove PostHog SDK entirely
- Type-safe access via computed property structs (`featureFlags.settings.showAppIconPicker`)
- Simple persistent cache: load from cache on launch, refresh from API in background
- Debug menu with local overrides (DEBUG builds only), reorganized to mirror flag hierarchy

## Files Deleted

- `Fuckify/Features/Settings/Managers/FeatureFlagsManager.swift`
- `Fuckify/Features/Settings/Config/SettingsConfig.swift`
- `Fuckify/Features/Settings/DataManagement/Config/ImportExportConfig.swift`
- `Fuckify/Features/Settings/Debug/SettingsFlagsDetailView.swift`
- `Fuckify/Features/Settings/Debug/ImportExportFlagsDetailView.swift`
- `Fuckify/Features/Settings/Debug/DebugMenuFlagDetailView.swift`

## Architecture

```
FeatureFlagKey (internal enum, flat, rawValue = API string)
    ↓
FeatureFlagsService (actor, fetches API, reads/writes UserDefaults cache)
    ↓
FeatureFlagsProvider (@Observable @MainActor, owns flags + overrides)
    ↓ via computed property structs
featureFlags.settings.showAppIconPicker
featureFlags.settings.data.showImportExport
featureFlags.settings.data.importExport.showCsvImportPartners
featureFlags.settings.more.showDebugMenu
```

`FeatureFlagsProvider` is created as `@State` in `FuckifyApp` and injected via `@Environment`, matching the pattern used by `securitySettings`, `userSettings`, etc.

## Section 1: Core Data Layer

### `FeatureFlagKey` (internal enum)

Defined as a private enum inside `FeatureFlagsProvider.swift`. Not exposed to views. Exists solely to prevent hardcoded strings at call sites inside the provider and service.

```swift
enum FeatureFlagKey: String {
    // settings.personalization
    case settingsPersonalizationAppIconPicker      = "settings.personalization.appIconPicker"
    case settingsPersonalizationActivities         = "settings.personalization.activities"
    case settingsPersonalizationProtectionMethods  = "settings.personalization.protectionMethods"
    case settingsPersonalizationPositions          = "settings.personalization.positions"
    case settingsPersonalizationSecurity           = "settings.personalization.security"
    case settingsPersonalizationAppIconPickerSpicyIcons = "settings.personalization.appIconPicker.spicyIcons"

    // settings.data
    case settingsDataImportExport                  = "settings.data.importExport"
    case settingsDataDeleteData                    = "settings.data.deleteData"

    // settings.data.importExport
    case settingsDataImportExportCsvImportPartners   = "settings.data.importExport.csvImportPartners"
    case settingsDataImportExportCsvImportEncounters = "settings.data.importExport.csvImportEncounters"
    case settingsDataImportExportCsvExportPartners   = "settings.data.importExport.csvExportPartners"
    case settingsDataImportExportCsvExportEncounters = "settings.data.importExport.csvExportEncounters"
    case settingsDataImportExportImportDatabase      = "settings.data.importExport.importDatabase"
    case settingsDataImportExportExportDatabase      = "settings.data.importExport.exportDatabase"

    // settings.more
    case settingsMoreAbout                         = "settings.more.about"
    case settingsMoreSupportApp                    = "settings.more.supportApp"
    case settingsMoreExperiments                   = "settings.more.experiments"
    case settingsMoreDebugMenu                     = "settings.more.debugMenu"
}
```

### `FeatureFlagsService` (actor)

Responsible only for networking and cache I/O. Not `@MainActor` — runs on background executor.

```swift
actor FeatureFlagsService {
    private let cacheKey = "feature_flags_cache"
    private let baseURL = "https://dev.coitalcomra.de/api/feature-flags"

    func fetchFlags() async throws -> [String: Bool]
    func cachedFlags() -> [String: Bool]   // reads UserDefaults
    func persistFlags(_ flags: [String: Bool])  // writes UserDefaults
    func clearCache()
    func lastFetchedDate() -> Date?
}
```

URL construction uses `Bundle.main` for version, build, and hardcodes `platform=ios`.  
Response decoded directly as `[String: Bool]` — no intermediate model needed.  
On any error (network, decode, 4xx, 5xx), `fetchFlags()` throws and the caller falls back to cache.

## Section 2: `FeatureFlagsProvider` and Computed Views

Single `@Observable @MainActor` class. Replaces `FeatureFlagsManager`, `SettingsConfig`, and `ImportExportConfig`.

```swift
@Observable
@MainActor
final class FeatureFlagsProvider {
    private(set) var flags: [String: Bool] = [:]
    private(set) var isLoaded: Bool = false
    #if DEBUG
    private var overrides: [String: Bool] = [:]  // persisted to UserDefaults
    #endif

    private let service = FeatureFlagsService()

    func load() async  // load cache → set isLoaded → fetch fresh → update flags

    func isEnabled(_ key: FeatureFlagKey) -> Bool {
        #if DEBUG
        if let override = overrides[key.rawValue] { return override }
        #endif
        return flags[key.rawValue] ?? false
    }

    #if DEBUG
    func setOverride(_ key: FeatureFlagKey, value: Bool?)  // nil = remove override
    func clearAllOverrides()
    func forceRefresh() async
    #endif

    // Domain views
    var settings: SettingsFlags { SettingsFlags(provider: self) }
}
```

### Computed Property Structs

Zero-cost value types, pure namespacing. Not `@Observable` — they read through `provider` which is observable.

```swift
struct SettingsFlags {
    let provider: FeatureFlagsProvider
    var showAppIconPicker: Bool { provider.isEnabled(.settingsPersonalizationAppIconPicker) }
    var showActivities: Bool    { provider.isEnabled(.settingsPersonalizationActivities) }
    var showProtectionMethods: Bool { provider.isEnabled(.settingsPersonalizationProtectionMethods) }
    var showPositions: Bool     { provider.isEnabled(.settingsPersonalizationPositions) }
    var showSecurity: Bool      { provider.isEnabled(.settingsPersonalizationSecurity) }

    var appIconPicker: AppIconPickerFlags { AppIconPickerFlags(provider: provider) }
    var data: SettingsDataFlags { SettingsDataFlags(provider: provider) }
    var more: SettingsMoreFlags { SettingsMoreFlags(provider: provider) }
}

// SettingsPersonalizationFlags is not needed — top-level personalization flags
// live directly on SettingsFlags. Sub-features of appIconPicker get their own struct:

struct AppIconPickerFlags {
    let provider: FeatureFlagsProvider
    var showSpicyIcons: Bool { provider.isEnabled(.settingsPersonalizationAppIconPickerSpicyIcons) }
}

struct SettingsDataFlags {
    let provider: FeatureFlagsProvider
    var showImportExport: Bool { provider.isEnabled(.settingsDataImportExport) }
    var showDeleteData: Bool   { provider.isEnabled(.settingsDataDeleteData) }
    var importExport: ImportExportFlags { ImportExportFlags(provider: provider) }
}

struct ImportExportFlags {
    let provider: FeatureFlagsProvider
    var showCsvImportPartners: Bool   { provider.isEnabled(.settingsDataImportExportCsvImportPartners) }
    var showCsvImportEncounters: Bool { provider.isEnabled(.settingsDataImportExportCsvImportEncounters) }
    var showCsvExportPartners: Bool   { provider.isEnabled(.settingsDataImportExportCsvExportPartners) }
    var showCsvExportEncounters: Bool { provider.isEnabled(.settingsDataImportExportCsvExportEncounters) }
    var showImportDatabase: Bool      { provider.isEnabled(.settingsDataImportExportImportDatabase) }
    var showExportDatabase: Bool      { provider.isEnabled(.settingsDataImportExportExportDatabase) }
}

struct SettingsMoreFlags {
    let provider: FeatureFlagsProvider
    var showAbout: Bool      { provider.isEnabled(.settingsMoreAbout) }
    var showSupportApp: Bool { provider.isEnabled(.settingsMoreSupportApp) }
    var showExperiments: Bool { provider.isEnabled(.settingsMoreExperiments) }
    var showDebugMenu: Bool  { provider.isEnabled(.settingsMoreDebugMenu) }
}
```

### Usage in views

```swift
// Injection in FuckifyApp
@State private var featureFlags = FeatureFlagsProvider()

ContentView()
    .environment(featureFlags)
    .task { await featureFlags.load() }

// In any view
@Environment(FeatureFlagsProvider.self) var featureFlags

if featureFlags.settings.showAppIconPicker { ... }
if featureFlags.settings.data.importExport.showCsvImportPartners { ... }
if featureFlags.settings.more.showDebugMenu { ... }
```

## Section 3: Debug Menu

### Structure

Single `DebugMenuView` with flags inline — no drill-down detail views. Sections mirror the dot-path hierarchy.

```
Debug Menu
├── Info banner (replaces PostHog explanation)
│
├── Section: "Actions"
│   ├── Reload Flags Now  [button, shows spinner]
│   └── Clear All Overrides  [button, destructive]
│
├── Section: "settings.personalization"
│   ├── appIconPicker             [DebugFlagRow toggle]
│   ├── activities                [DebugFlagRow toggle]
│   ├── protectionMethods         [DebugFlagRow toggle]
│   ├── positions                 [DebugFlagRow toggle]
│   ├── security                  [DebugFlagRow toggle]
│   └── appIconPicker.spicyIcons  [DebugFlagRow toggle, indented]
│
├── Section: "settings.data"
│   ├── importExport              [DebugFlagRow toggle]
│   ├── deleteData                [DebugFlagRow toggle]
│   ├── importExport.csvImportPartners    [DebugFlagRow toggle, indented]
│   ├── importExport.csvImportEncounters  [DebugFlagRow toggle, indented]
│   ├── importExport.csvExportPartners    [DebugFlagRow toggle, indented]
│   ├── importExport.csvExportEncounters  [DebugFlagRow toggle, indented]
│   ├── importExport.importDatabase       [DebugFlagRow toggle, indented]
│   └── importExport.exportDatabase       [DebugFlagRow toggle, indented]
│
├── Section: "settings.more"
│   ├── about        [DebugFlagRow toggle]
│   ├── supportApp   [DebugFlagRow toggle]
│   ├── experiments  [DebugFlagRow toggle]
│   └── debugMenu    [DebugFlagRow toggle]
│
└── Section: "App Info"
    ├── Version         [LabeledContent]
    ├── Last Fetched    [LabeledContent, shows date or "Never"]
    └── Clear Flag Cache  [button, destructive]
```

### `DebugFlagRow` changes

Gains an "overridden" visual indicator — an orange dot or badge — when the displayed value differs from the API value (i.e. a local override is active).

Toggle writes directly to `featureFlags.setOverride(key, value:)`.

### Override persistence

Overrides stored in UserDefaults under a separate key from the flag cache. Survive app restarts. Cleared by "Clear All Overrides" button or by removing the app.

## Section 4: Fetch, Cache, and App Startup

### Cache behavior

1. On `load()`: read UserDefaults cache → populate `flags` → set `isLoaded = true`
2. Fire background `Task` to fetch fresh from API
3. On success: update `flags`, persist new cache
4. On failure: log warning, keep existing cached values, no user-visible error

First launch (no cache): `flags` is empty, all `isEnabled()` calls return `false` until fetch completes.

### App startup

```swift
// FuckifyApp
@State private var featureFlags = FeatureFlagsProvider()

// In WindowGroup body:
ContentView()
    .environment(featureFlags)
    .task { await featureFlags.load() }
```

Remove from `FuckifyApp.init()`:
- `PostHogSDK.shared.setup(config)`
- `PostHogSDK.shared.setPersonPropertiesForFlags(...)`
- All PostHog config construction

### PostHog removal checklist

- Remove `import PostHog` from `FuckifyApp.swift`, `DebugMenuView.swift`
- Remove PostHog package from Xcode project (Swift Package Manager)
- Delete `FeatureFlagsManager.swift` (entire file)
- Delete `SettingsConfig.swift` (entire file)
- Delete `ImportExportConfig.swift` (entire file)
- Delete `SettingsFlagsDetailView.swift`, `ImportExportFlagsDetailView.swift`, `DebugMenuFlagDetailView.swift`
- Update all views that reference `SettingsConfig.shared` or `ImportExportConfig.shared` to use `@Environment(FeatureFlagsProvider.self)`

## New Files

| File | Purpose |
|------|---------|
| `Fuckify/Features/FeatureFlags/FeatureFlagsService.swift` | Actor: networking + cache I/O |
| `Fuckify/Features/FeatureFlags/FeatureFlagsProvider.swift` | Private FeatureFlagKey enum + @Observable provider + domain view structs |
| `Fuckify/Features/Settings/Debug/DebugMenuView.swift` | Rewritten (replaces current) |
| `Fuckify/Features/Settings/Debug/DebugFlagRow.swift` | Updated (adds override indicator) |
