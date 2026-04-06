//
//  ImportExportFlagsDetailView.swift
//  Fuckify
//
//  Detail view for CCImportExportFlags feature flag
//

import SwiftUI

struct ImportExportFlagsDetailView: View {
    @State private var config = ImportExportConfig.shared
    
    var body: some View {
        Form {
            Section {
                Text("Controls which import/export options are visible in the Import & Export screen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("CSV Import") {
                DebugFlagRow(label: "Import Partners", value: $config.showImportPartners)
                DebugFlagRow(label: "Import Encounters", value: $config.showImportEncounters)
            }
            
            Section("CSV Export") {
                DebugFlagRow(label: "Export Partners", value: $config.showExportPartners)
                DebugFlagRow(label: "Export Encounters", value: $config.showExportEncounters)
            }
            
            Section("Database") {
                DebugFlagRow(label: "Import Database", value: $config.showImportDatabase)
                DebugFlagRow(label: "Export Database", value: $config.showExportDatabase)
            }
        }
        .navigationTitle("CCImportExportFlags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ImportExportFlagsDetailView()
    }
}
