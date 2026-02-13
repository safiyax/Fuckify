//
//  FeatureFlagsManager.swift
//  Fuckify
//
//  Centralized feature flag management using PostHog
//  Handles fetching, caching, and version-based reload logic
//

import Foundation
import PostHog

// MARK: - Models for JSON Payloads

struct ImportExportFlagsPayload: Codable {
    let csv: CSVFlags
    let database: DatabaseFlags
    
    struct CSVFlags: Codable {
        let showImportPartners: Bool
        let showImportEncounters: Bool
        let showExportPartners: Bool
        let showExportEncounters: Bool
        
        enum CodingKeys: String, CodingKey {
            case showImportPartners = "show_import_partners"
            case showImportEncounters = "show_import_encounters"
            case showExportPartners = "show_export_partners"
            case showExportEncounters = "show_export_encounters"
        }
    }
    
    struct DatabaseFlags: Codable {
        let showImportDatabase: Bool
        let showExportDatabase: Bool
        
        enum CodingKeys: String, CodingKey {
            case showImportDatabase = "show_import_database"
            case showExportDatabase = "show_export_database"
        }
    }
}

struct SettingsFlagsPayload: Codable {
    let personalization: PersonalizationFlags
    let data: DataFlags
    let more: MoreFlags
    
    struct PersonalizationFlags: Codable {
        let showAppIconPicker: Bool
        let showActivities: Bool
        let showProtectionMethods: Bool
        let showSecurity: Bool
        
        enum CodingKeys: String, CodingKey {
            case showAppIconPicker = "show_app_icon_picker"
            case showActivities = "show_activities"
            case showProtectionMethods = "show_protection_methods"
            case showSecurity = "show_security"
        }
    }
    
    struct DataFlags: Codable {
        let showImportExport: Bool
        let showDeleteData: Bool
        
        enum CodingKeys: String, CodingKey {
            case showImportExport = "show_import_export"
            case showDeleteData = "show_delete_data"
        }
    }
    
    struct MoreFlags: Codable {
        let showAbout: Bool
        let showSupport: Bool
        let showExperiments: Bool
        
        enum CodingKeys: String, CodingKey {
            case showAbout = "show_about"
            case showSupport = "show_support"
            case showExperiments = "show_experiments"
        }
    }
}

// MARK: - Feature Flags Manager

@MainActor
@Observable
class FeatureFlagsManager {
    static let shared = FeatureFlagsManager()
    
    // MARK: - Flag Names
    
    private let settingsFlagName = "CCSettingsFlags"
    private let importExportFlagName = "CCImportExportFlags"
    private let debugMenuFlagName = "CCDebugMenu"
    private let versionKey = "last_flags_version"
    
    // MARK: - Published State
    
    var isDebugMenuEnabled: Bool = false
    var settingsFlags: SettingsFlagsPayload? {
        didSet {
            notifyConfigsOfUpdate()
        }
    }
    var importExportFlags: ImportExportFlagsPayload? {
        didSet {
            notifyConfigsOfUpdate()
        }
    }
    var didLoadFlags: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        Task {
            await loadFlags()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all flags from PostHog
    /// In production: Only reloads if app version has changed
    /// In debug mode: Reloads on every app launch
    func loadFlags() async {
        let currentVersion = getCurrentAppVersion()
        let lastVersion = UserDefaults.standard.string(forKey: versionKey)
        
        // Always check debug menu flag first
        isDebugMenuEnabled = PostHogSDK.shared.isFeatureEnabled(debugMenuFlagName)
        
        // In debug mode, always reload. Otherwise, only reload if version changed
        let shouldReload = isDebugMenuEnabled || lastVersion != currentVersion
        
        guard shouldReload else {
            return
        }
        
        // Fetch settings flags
        settingsFlags = getSettingsFlagsPayload()
        
        // Fetch import/export flags
        importExportFlags = getImportExportFlagsPayload()
        
        // Save current version (only matters in production mode)
        UserDefaults.standard.set(currentVersion, forKey: versionKey)
        
        // Mark as loaded
        didLoadFlags = true
    }
    
    /// Force reload all flags (for debug menu)
    func forceReloadFlags() async {
        PostHogSDK.shared.reloadFeatureFlags()
        
        // Small delay to let PostHog refresh
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isDebugMenuEnabled = PostHogSDK.shared.isFeatureEnabled(debugMenuFlagName)
        settingsFlags = getSettingsFlagsPayload()
        importExportFlags = getImportExportFlagsPayload()
    }
    
    /// Check if a boolean feature flag is enabled
    func isFeatureEnabled(_ flagName: String) -> Bool {
        return PostHogSDK.shared.isFeatureEnabled(flagName)
    }
    
    /// Get a feature flag payload
    func getFeatureFlagPayload<T: Codable>(_ flagName: String, type: T.Type) -> T? {
        let result = PostHogSDK.shared.getFeatureFlagResult(flagName)
        
        guard let payloadJson = result?.payload else {
            return nil
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payloadJson),
              let payload = try? JSONDecoder().decode(T.self, from: jsonData) else {
            return nil
        }
        
        return payload
    }
    
    /// Get the last version when flags were loaded
    func getLastFlagsVersion() -> String? {
        return UserDefaults.standard.string(forKey: versionKey)
    }
    
    /// Clear the version cache (forces reload on next launch)
    func clearVersionCache() {
        UserDefaults.standard.removeObject(forKey: versionKey)
    }
    
    // MARK: - Private Methods
    
    private func getSettingsFlagsPayload() -> SettingsFlagsPayload? {
        return getFeatureFlagPayload(settingsFlagName, type: SettingsFlagsPayload.self)
    }
    
    private func getImportExportFlagsPayload() -> ImportExportFlagsPayload? {
        return getFeatureFlagPayload(importExportFlagName, type: ImportExportFlagsPayload.self)
    }
    
    private func getCurrentAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version).\(build)"
    }
    
    private func notifyConfigsOfUpdate() {
        // Notify configs to refresh from flags
        Task { @MainActor in
            SettingsConfig.shared.refreshFromFlags()
            ImportExportConfig.shared.refreshFromFlags()
        }
    }
}
