//
//  FeatureFlagsProvider.swift
//  Fuckify
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "FeatureFlags")

// MARK: - Internal Key Enum (not exposed to views)

private enum FeatureFlagKey: String, CaseIterable {
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

    fileprivate func isEnabled(_ key: FeatureFlagKey) -> Bool {
        #if DEBUG
        if let override = overrides[key.rawValue] {
            return override
        }
        #endif
        return flags[key.rawValue] ?? false
    }

    // MARK: - Debug Overrides

    #if DEBUG
    fileprivate func setOverride(_ key: FeatureFlagKey, value: Bool?) {
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

    // Called by DebugMenuView which works with raw key strings directly
    func setOverrideRaw(_ rawKey: String, value: Bool) {
        assert(FeatureFlagKey(rawValue: rawKey) != nil, "setOverrideRaw called with unknown flag key: \(rawKey)")
        overrides[rawKey] = value
        persistOverrides()
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

@MainActor
struct SettingsFlags {
    let provider: FeatureFlagsProvider

    var showAppIconPicker: Bool     { provider.isEnabled(.settingsPersonalizationAppIconPicker) }
    var showActivities: Bool        { provider.isEnabled(.settingsPersonalizationActivities) }
    var showProtectionMethods: Bool { provider.isEnabled(.settingsPersonalizationProtectionMethods) }
    var showPositions: Bool         { provider.isEnabled(.settingsPersonalizationPositions) }
    var showSecurity: Bool          { provider.isEnabled(.settingsPersonalizationSecurity) }

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

@MainActor
struct AppIconPickerFlags {
    let provider: FeatureFlagsProvider
    var showSpicyIcons: Bool { provider.isEnabled(.settingsPersonalizationAppIconPickerSpicyIcons) }
}

// MARK: - SettingsDataFlags

@MainActor
struct SettingsDataFlags {
    let provider: FeatureFlagsProvider
    var showImportExport: Bool { provider.isEnabled(.settingsDataImportExport) }
    var showDeleteData: Bool   { provider.isEnabled(.settingsDataDeleteData) }
    var importExport: ImportExportFlags { ImportExportFlags(provider: provider) }
}

// MARK: - ImportExportFlags

@MainActor
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

@MainActor
struct SettingsMoreFlags {
    let provider: FeatureFlagsProvider
    var showAbout: Bool       { provider.isEnabled(.settingsMoreAbout) }
    var showSupportApp: Bool  { provider.isEnabled(.settingsMoreSupportApp) }
    var showExperiments: Bool { provider.isEnabled(.settingsMoreExperiments) }
    var showDebugMenu: Bool   { provider.isEnabled(.settingsMoreDebugMenu) }
}
