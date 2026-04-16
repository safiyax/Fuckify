//
//  SettingsFlagsDetailView.swift
//  Fuckify
//
//  Detail view for CCSettingsFlags feature flag
//

import SwiftUI

struct SettingsFlagsDetailView: View {
    @State private var config = SettingsConfig.shared
    
    var body: some View {
        Form {
            Section {
                Text("Controls which settings options are visible in the Settings screen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section("Personalization") {
                DebugFlagRow(label: "App Icon Picker", value: $config.showAppIconPicker)
                DebugFlagRow(label: "Activities", value: $config.showActivities)
                DebugFlagRow(label: "Protection Methods", value: $config.showProtectionMethods)
                DebugFlagRow(label: "Positions", value: $config.showPositions)
                DebugFlagRow(label: "Security", value: $config.showSecurity)
            }
            
            Section("Data") {
                DebugFlagRow(label: "Import & Export", value: $config.showImportExport)
                DebugFlagRow(label: "Delete Data", value: $config.showDeleteData)
            }
            
            Section("More") {
                DebugFlagRow(label: "About", value: $config.showAbout)
                DebugFlagRow(label: "Support", value: $config.showSupport)
                DebugFlagRow(label: "Experiments", value: $config.showExperiments)
            }
        }
        .navigationTitle("CCSettingsFlags")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsFlagsDetailView()
    }
}
