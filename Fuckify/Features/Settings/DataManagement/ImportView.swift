//
//  ImportView.swift
//  Fuckify
//
//

import SwiftUI
import Dependencies
import UniformTypeIdentifiers
import SQLiteData

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "ImportExport")

extension UTType {
    static var database: UTType {
        // Use .data to accept any file, or create a specific one for .db files
        UTType(filenameExtension: "db") ?? .data
    }
}

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @Dependency(\.partnerService) private var partnerService
    @Dependency(\.encounterService) private var encounterService
    @Dependency(\.databaseService) private var databaseService
    
    @State private var allPartners: [SQLPartner] = []
    @State private var allEncounters: [SQLEncounter] = []
    @State private var showingPartnerImport = false
    @State private var showingEncounterImport = false
    @State private var partnerExportURL: URL?
    @State private var encounterExportURL: URL?
    @State private var databaseExportURL: URL?
    @State private var showingDatabaseImport = false
    @State private var showingImportConfirmation = false
    @State private var importError: String?
    @State private var showingImportError = false
    @State private var selectedDatabaseURL: URL?
    @State private var showingImportSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Import Section
                    if featureFlags.settings.data.importExport.showImportCSVSection {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                Text("Import")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                Button(action: { showingPartnerImport = true }) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                            .frame(width: 50)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Import Partners")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Add partners from a CSV file")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { showingEncounterImport = true }) {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .font(.title2)
                                            .foregroundColor(.pink)
                                            .frame(width: 50)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Import Encounters")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text("Add encounters from a CSV file")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Export Section
                    if featureFlags.settings.data.importExport.showExportCSVSection {
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                
                                Text("Export")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            VStack(spacing: 12) {
                                if let url = partnerExportURL {
                                    ShareLink(item: url) {
                                        HStack {
                                            Image(systemName: "person.2.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Export Partners")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text("\(allPartners.count) partners")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: { exportPartners() }) {
                                        HStack {
                                            Image(systemName: "person.2.fill")
                                                .font(.title2)
                                                .foregroundColor(.blue)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Export Partners")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text("\(allPartners.count) partners")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(allPartners.isEmpty)
                                    .opacity(allPartners.isEmpty ? 0.5 : 1.0)
                                }
                                
                                if let url = encounterExportURL {
                                    ShareLink(item: url) {
                                        HStack {
                                            Image(systemName: "heart.fill")
                                                .font(.title2)
                                                .foregroundColor(.pink)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Export Encounters")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text("\(allEncounters.count) encounters")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button(action: { exportEncounters() }) {
                                        HStack {
                                            Image(systemName: "heart.fill")
                                                .font(.title2)
                                                .foregroundColor(.pink)
                                                .frame(width: 50)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Export Encounters")
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                
                                                Text("\(allEncounters.count) encounters")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(allEncounters.isEmpty)
                                    .opacity(allEncounters.isEmpty ? 0.5 : 1.0)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Advanced Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "gearshape.2")
                                .font(.title2)
                                .foregroundColor(.orange)

                            Text("Advanced")
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            // Import Database Button
                            Button(action: { showingDatabaseImport = true }) {
                                HStack {
                                    Image(systemName: "cylinder.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                        .frame(width: 50)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Import Database")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text("Replace current database")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                            
                            // Export Database Button
                            if let url = databaseExportURL {
                                ShareLink(item: url) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                            .frame(width: 50)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Export Database")
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text("Raw SQLite database file")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: { exportDatabase() }) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                            .font(.title2)
                                            .foregroundColor(.orange)
                                            .frame(width: 50)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Export Database")
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text("Raw SQLite database file")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPartnerImport) {
                PartnerImportView()
            }
            .sheet(isPresented: $showingEncounterImport) {
                EncounterImportView()
            }
            .fileImporter(
                isPresented: $showingDatabaseImport,
                allowedContentTypes: [.database, .item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    if let fileURL = files.first {
                        handleDatabaseImport(from: fileURL)
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                    showingImportError = true
                }
            }
            .alert("Import Database", isPresented: $showingImportConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Replace", role: .destructive) {
                    Task {
                        await performDatabaseImport()
                    }
                }
            } message: {
                Text("This will replace your current database with the imported one. All existing data will be lost. This cannot be undone.")
            }
            .alert("Import Error", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Unknown error occurred")
            }
            .alert("Import Successful", isPresented: $showingImportSuccess) {
                Button("OK") { }
            } message: {
                Text("Database imported successfully.")
            }
            .task {
                await loadData()
            }
            .onChange(of: showingPartnerImport) { _, isShowing in
                if !isShowing {
                    // Sheet was dismissed, reload data
                    Task {
                        await loadData()
                    }
                }
            }
            .onChange(of: showingEncounterImport) { _, isShowing in
                if !isShowing {
                    // Sheet was dismissed, reload data
                    Task {
                        await loadData()
                    }
                }
            }
            .onAppear {
                // Pre-generate export files so ShareLink has them ready
                if !allPartners.isEmpty && partnerExportURL == nil {
                    exportPartners()
                }
                if !allEncounters.isEmpty && encounterExportURL == nil {
                    exportEncounters()
                }
                if databaseExportURL == nil {
                    exportDatabase()
                }
            }
        }
    }
    
    private func loadData() async {
        if let partners = try? partnerService.fetchAll() {
            allPartners = partners
        }
        if let encounters = try? encounterService.fetchAll() {
            allEncounters = encounters
        }
    }

    private func exportPartners() {
        var csvString = "name,phoneNumber,notes,relationshipType,dateMet\n"
        
        let created = Date()
        
        for partner in allPartners {
            let name = escapeCSVField(partner.name)
            let phoneNumber = escapeCSVField(partner.phoneNumber)
            let notes = escapeCSVField(partner.notes)
            let relationshipType = partner.relationshipType.rawValue
            let dateMet = partner.dateMet != nil ? Formatters.iso8601DateOnly.string(from: partner.dateMet!) : ""

            csvString += "\(name),\(phoneNumber),\(notes),\(relationshipType),\(dateMet)\n"
        }
        
        logger.debug("CSV generation time: \(Date().timeIntervalSince(created))s")

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("partners_export.csv")

        do {
            let created = Date()
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.debug("CSV write time: \(Date().timeIntervalSince(created))s")
            partnerExportURL = fileURL
        } catch {
            logger.error("Failed to write CSV: \(error)")
        }
    }

    private func exportEncounters() {
        var csvString = "date,duration,activities,protectionMethods,location,notes,rating,reachedOrgasm,partnerNames\n"

        for encounter in allEncounters {
            let date = encounter.date != nil ? Formatters.iso8601DateOnly.string(from: encounter.date!) : ""
            let duration = String(Int(encounter.duration / 60)) // Convert to minutes
            
            // Load activities and protection methods for this encounter (NEW: entity-based)
            let activityEntities = (try? encounterService.fetchActivityEntities(for: encounter.id)) ?? []
            let protectionEntities = (try? encounterService.fetchProtectionMethodEntities(for: encounter.id)) ?? []
            let partners = (try? encounterService.fetchPartners(for: encounter.id)) ?? []
            
            let activitiesStr = escapeCSVField(activityEntities.map { $0.name }.joined(separator: ", "))
            let protectionMethodsStr = escapeCSVField(protectionEntities.map { $0.name }.joined(separator: ", "))
            let location = escapeCSVField(encounter.location)
            let notes = escapeCSVField(encounter.notes)
            let rating = String(encounter.rating)
            let reachedOrgasm = encounter.reachedOrgasm ? "true" : "false"
            let partnerNames = escapeCSVField(partners.map { $0.name }.joined(separator: ", "))

            csvString += "\(date),\(duration),\(activitiesStr),\(protectionMethodsStr),\(location),\(notes),\(rating),\(reachedOrgasm),\(partnerNames)\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("encounters_export.csv")

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            encounterExportURL = fileURL
        } catch {
            logger.error("Failed to write encounters CSV: \(error)")
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
    
    private func exportDatabase() {
        do {
            // Build the destination path in the temp directory
            let tempDir = FileManager.default.temporaryDirectory
            let timestamp = Formatters.iso8601Full.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let fileURL = tempDir.appendingPathComponent("CoitalComrade_\(timestamp).db")
            
            // Use GRDB's backup API so WAL-mode data is fully flushed into the
            // exported file. A raw FileManager.copyItem would miss any pages
            // that are still in the WAL file and not yet checkpointed.
            try databaseService.exportDatabase(to: fileURL)
            
            logger.info("Database exported to: \(fileURL.path)")
            databaseExportURL = fileURL
        } catch {
            logger.error("Failed to export database: \(error)")
        }
    }
    
    private func handleDatabaseImport(from url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else {
            importError = "Unable to access the selected file"
            showingImportError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        // Verify it's a valid database file
        guard FileManager.default.fileExists(atPath: url.path) else {
            importError = "Selected file does not exist"
            showingImportError = true
            return
        }
        
        // Store the URL and show confirmation
        selectedDatabaseURL = url
        showingImportConfirmation = true
    }
    
    private func performDatabaseImport() async {
        guard let sourceURL = selectedDatabaseURL else {
            importError = "No file selected"
            showingImportError = true
            return
        }

        guard sourceURL.startAccessingSecurityScopedResource() else {
            importError = "Unable to access the selected file"
            showingImportError = true
            return
        }

        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }

        do {
            try databaseService.importDatabase(from: sourceURL)
            logger.info("Database imported successfully from: \(sourceURL.path)")

            selectedDatabaseURL = nil

            await MainActor.run {
                showingImportSuccess = true
            }
        } catch {
            importError = "Failed to import database: \(error.localizedDescription)"
            showingImportError = true
            logger.error("Failed to import database: \(error)")
        }
    }
}

#Preview {
    ImportView()
}
