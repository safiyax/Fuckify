//
//  ImportExportConfig.swift
//  Fuckify
//
//  Configuration file to control which import/export options are visible
//  Uses FeatureFlagsManager to fetch configuration from PostHog with fallback to defaults
//

import Foundation

@MainActor
@Observable
class ImportExportConfig {
    static let shared = ImportExportConfig()
    
    // MARK: - Published Properties
    
    // CSV Section
    var showImportPartners: Bool
    var showImportEncounters: Bool
    var showExportPartners: Bool
    var showExportEncounters: Bool
    
    // Database Section
    var showImportDatabase: Bool
    var showExportDatabase: Bool
    
    // MARK: - Private Properties
    
    private let flagsManager = FeatureFlagsManager.shared
    
    // Hardcoded fallback defaults
    private let defaults = ImportExportFlagsPayload(
        csv: .init(
            showImportPartners: false,
            showImportEncounters: false,
            showExportPartners: false,
            showExportEncounters: false
        ),
        database: .init(
            showImportDatabase: true,
            showExportDatabase: true
        )
    )
    
    // MARK: - Initialization
    
    private init() {
        // Initialize with defaults first
        self.showImportPartners = defaults.csv.showImportPartners
        self.showImportEncounters = defaults.csv.showImportEncounters
        self.showExportPartners = defaults.csv.showExportPartners
        self.showExportEncounters = defaults.csv.showExportEncounters
        
        self.showImportDatabase = defaults.database.showImportDatabase
        self.showExportDatabase = defaults.database.showExportDatabase
        
        // Apply flags if already loaded (e.g., on subsequent initializations)
        refreshFromFlags()
    }
    
    // MARK: - Public Methods
    
    /// Refresh settings from feature flags manager
    func refreshFromFlags() {
        if let payload = flagsManager.importExportFlags {
            applyPayload(payload)
        }
    }
    
    // MARK: - Private Methods
    
    private func applyPayload(_ payload: ImportExportFlagsPayload) {
        // CSV
        showImportPartners = payload.csv.showImportPartners
        showImportEncounters = payload.csv.showImportEncounters
        showExportPartners = payload.csv.showExportPartners
        showExportEncounters = payload.csv.showExportEncounters
        
        // Database
        showImportDatabase = payload.database.showImportDatabase
        showExportDatabase = payload.database.showExportDatabase
    }
    
    // MARK: - Section Visibility Helpers
    
    /// Whether to show the entire import CSV section
    var showImportCSVSection: Bool {
        showImportPartners || showImportEncounters
    }
    
    /// Whether to show the entire export CSV section
    var showExportCSVSection: Bool {
        showExportPartners || showExportEncounters
    }
    
    /// Whether to show the entire database section
    var showDatabaseSection: Bool {
        showImportDatabase || showExportDatabase
    }
}
