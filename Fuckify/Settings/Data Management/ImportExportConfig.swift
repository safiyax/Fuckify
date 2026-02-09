//
//  SettingsConfig.swift
//  Fuckify
//
//  Configuration file to control which settings options are visible
//

import Foundation

struct ImportExportConfig {
    static let shared = ImportExportConfig()
    
    // MARK: - CSV
    
    /// Show/hide import partners
    let showImportPartners = false
    
    /// Show/hide import encounters
    let showImportEncounters = false
    
    /// Show/hide export partners
    let showExportPartners = false
    
    /// Show/hide export encounters
    let showExportEncounters = false
    
    // MARK: - Database
    
    /// Show/hide import database
    let showImportDatabase = true
    
    /// Show/hide export database
    let showExportDatabase = true
    
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
