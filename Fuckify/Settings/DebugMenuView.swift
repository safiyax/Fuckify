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
                            await config.forceReloadFlags()
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
                
                Section("Current Flag Values") {
                    Group {
                        DebugFlagRow(label: "App Icon Picker", value: $config.showAppIconPicker)
                        DebugFlagRow(label: "Activities", value: $config.showActivities)
                        DebugFlagRow(label: "Protection Methods", value: $config.showProtectionMethods)
                        DebugFlagRow(label: "Security", value: $config.showSecurity)
                    }
                    
                    Group {
                        DebugFlagRow(label: "Import & Export", value: $config.showImportExport)
                        DebugFlagRow(label: "Delete Data", value: $config.showDeleteData)
                    }
                    
                    Group {
                        DebugFlagRow(label: "About", value: $config.showAbout)
                        DebugFlagRow(label: "Support", value: $config.showSupport)
                        DebugFlagRow(label: "Experiments", value: $config.showExperiments)
                    }
                    
                    DebugFlagRow(label: "Debug Menu", value: $config.showDebugMenu)
                }
                
                Section("App Info") {
                    LabeledContent("Version", value: getCurrentAppVersion())
                    LabeledContent("PostHog Distinct ID", value: PostHogSDK.shared.getDistinctId() ?? "Unknown")
                    LabeledContent("Last Flags Version", value: UserDefaults.standard.string(forKey: "last_flags_version") ?? "Never loaded")
                }
                
                Section("Actions") {
                    Button {
                        UserDefaults.standard.removeObject(forKey: "last_flags_version")
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
                    Button("Close") {
                        dismiss()
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
}

struct DebugFlagRow: View {
    let label: String
    @Binding var value: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(value ? .green : .red)
                .font(.body)
            
            Text(label)
            
            Spacer()
            
            Toggle("", isOn: $value)
                .labelsHidden()
        }
    }
}

#Preview {
    DebugMenuView()
}
