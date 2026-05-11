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
    
    // settings.more.experiments
    case settingsMoreExperimentsUserRegistration    = "settings.more.experiments.userRegistration"
    case settingsMoreExperimentsPaywall             = "settings.more.experiments.paywall"
    case settingsMoreExperimentsSheetRedesign       = "settings.more.experiments.sheetRedesign"
    case settingsMoreExperimentsAnimatedBackground  = "settings.more.experiments.animatedBackground"
}

// MARK: - Provider

@Observable
@MainActor
final class FeatureFlagsProvider {
    private(set) var flags: [String: FlagValue] = [:]
    private(set) var isLoaded: Bool = false

    private(set) var overrides: [String: Bool] = [:]
    private let overridesKey = "feature_flags_overrides"

    private let service = FeatureFlagsService()

    // MARK: - Lifecycle

    func load() async {
        // 1. Load from cache immediately
        let cached = await service.cachedFlags()
        flags = cached
        isLoaded = true
        logger.debug("Loaded \(cached.count) flags from cache")

        loadOverrides()

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
        if let override = overrides[key.rawValue] {
            return override
        }
        return flags[key.rawValue]?.enabled ?? false
    }

    fileprivate func isPremiumFeature(_ key: FeatureFlagKey) -> Bool {
        flags[key.rawValue]?.premium ?? false
    }

    // MARK: - Debug Overrides

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

    // MARK: - Domain Views

    var settings: SettingsFlags { SettingsFlags(provider: self) }
}

// MARK: - SettingsFlags

@MainActor
struct SettingsFlags {
    let provider: FeatureFlagsProvider

    var appIconPicker: Bool         { provider.isEnabled(.settingsPersonalizationAppIconPicker) }
    var activities: Bool            { provider.isEnabled(.settingsPersonalizationActivities) }
    var protectionMethods: Bool     { provider.isEnabled(.settingsPersonalizationProtectionMethods) }
    var positions: Bool             { provider.isEnabled(.settingsPersonalizationPositions) }
    var security: Bool              { provider.isEnabled(.settingsPersonalizationSecurity) }

    var appIconPickerFlags: AppIconPickerFlags { AppIconPickerFlags(provider: provider) }
    var data: SettingsDataFlags               { SettingsDataFlags(provider: provider) }
    var more: SettingsMoreFlags               { SettingsMoreFlags(provider: provider) }

    // Section-level helpers
    var personalizationSection: Bool {
        appIconPicker || activities || protectionMethods || positions || security
    }
    var dataSection: Bool { data.importExport || data.deleteData }

    var moreSection: Bool { more.about || more.supportApp || more.experiments }
}

// MARK: - AppIconPickerFlags

@MainActor
struct AppIconPickerFlags {
    let provider: FeatureFlagsProvider
    var spicyIcons: Bool { provider.isEnabled(.settingsPersonalizationAppIconPickerSpicyIcons) }
}

// MARK: - SettingsDataFlags

@MainActor
struct SettingsDataFlags {
    let provider: FeatureFlagsProvider
    var importExport: Bool { provider.isEnabled(.settingsDataImportExport) }
    var deleteData: Bool   { provider.isEnabled(.settingsDataDeleteData) }
    var importExportFlags: ImportExportFlags { ImportExportFlags(provider: provider) }
}

// MARK: - ImportExportFlags

@MainActor
struct ImportExportFlags {
    let provider: FeatureFlagsProvider
    var csvImportPartners: Bool   { provider.isEnabled(.settingsDataImportExportCsvImportPartners) }
    var csvImportEncounters: Bool { provider.isEnabled(.settingsDataImportExportCsvImportEncounters) }
    var csvExportPartners: Bool   { provider.isEnabled(.settingsDataImportExportCsvExportPartners) }
    var csvExportEncounters: Bool { provider.isEnabled(.settingsDataImportExportCsvExportEncounters) }
    var importDatabase: Bool      { provider.isEnabled(.settingsDataImportExportImportDatabase) }
    var exportDatabase: Bool      { provider.isEnabled(.settingsDataImportExportExportDatabase) }

    // Section-level helpers (used by ImportView)
    var importCSVSection: Bool { csvImportPartners || csvImportEncounters }
    var exportCSVSection: Bool { csvExportPartners || csvExportEncounters }
}

// MARK: - SettingsMoreFlags

@MainActor
struct SettingsMoreFlags {
    let provider: FeatureFlagsProvider
    var about: Bool       { provider.isEnabled(.settingsMoreAbout) }
    var supportApp: Bool  { provider.isEnabled(.settingsMoreSupportApp) }
    var experiments: Bool { provider.isEnabled(.settingsMoreExperiments) }
    var debugMenu: Bool   { provider.isEnabled(.settingsMoreDebugMenu) }
    var experimentsFlags: ExperimentsFlags { ExperimentsFlags(provider: provider) }
}

// MARK: - ExperimentsFlags

@MainActor
struct ExperimentsFlags {
    let provider: FeatureFlagsProvider
    var userRegistration: Bool { provider.isEnabled(.settingsMoreExperimentsUserRegistration) }
    var paywall: Bool          { provider.isEnabled(.settingsMoreExperimentsPaywall) }
    var sheetRedesign: Bool    { provider.isEnabled(.settingsMoreExperimentsSheetRedesign) }
    var animatedBackground: Bool { provider.isEnabled(.settingsMoreExperimentsAnimatedBackground) }
}
