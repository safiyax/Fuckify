//
//  DebugMenuView.swift
//  Fuckify
//
//  Debug menu for internal testing - controlled by CCDebugMenu feature flag
//

import SwiftUI
import PostHog

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = SettingsConfig.shared
    @State private var flagsManager = FeatureFlagsManager.shared
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This menu is only visible when the **CCDebugMenu** feature flag is enabled in PostHog.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("When debug mode is active, settings flags are checked on **every app launch**. In production, they're only checked when the app version changes.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                Section("Feature Flags") {
                    Button {
                        Task {
                            isRefreshing = true
                            await flagsManager.forceReloadFlags()
                            config.refreshFromFlags()
                            isRefreshing = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reload Flags from PostHog")
                            Spacer()
                            if isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRefreshing)
                }
                
                Section("Feature Flags") {
                    NavigationLink {
                        SettingsFlagsDetailView()
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.blue)
                            Text("CCSettingsFlags")
                            Spacer()
                            Text("\(getSettingsFlagsCount()) flags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        ImportExportFlagsDetailView()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .foregroundColor(.green)
                            Text("CCImportExportFlags")
                            Spacer()
                            Text("\(getImportExportFlagsCount()) flags")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        DebugMenuFlagDetailView()
                    } label: {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.red)
                            Text("CCDebugMenu")
                            Spacer()
                            Text("1 flag")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("App Info") {
                    LabeledContent("Version", value: getCurrentAppVersion())
                    LabeledContent("PostHog Distinct ID", value: PostHogSDK.shared.getDistinctId())
                    LabeledContent("Last Flags Version", value: flagsManager.getLastFlagsVersion() ?? "Never loaded")
                }
                
                Section("Actions") {
                    Button {
                        flagsManager.clearVersionCache()
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Version Cache")
                        }
                    }
                    
                    Button {
                        PostHogSDK.shared.reset()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.xmark")
                                .foregroundColor(.orange)
                            Text("Reset PostHog Identity")
                        }
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Close", systemImage: "xmark")
                    }
                }
            }
        }
    }
    
    private func getCurrentAppVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    private func getSettingsFlagsCount() -> Int {
        return 9 // showAppIconPicker, showActivities, showProtectionMethods, showSecurity, showImportExport, showDeleteData, showAbout, showSupport, showExperiments
    }
    
    private func getImportExportFlagsCount() -> Int {
        return 6 // showImportPartners, showImportEncounters, showExportPartners, showExportEncounters, showImportDatabase, showExportDatabase
    }
}

#Preview {
    DebugMenuView()
}
