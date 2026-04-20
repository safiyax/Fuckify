//
//  DebugMenuView.swift
//  Fuckify
//
//  Debug menu — only visible when settings.more.debugMenu flag is enabled.
//  Flags are organized by their dot-path hierarchy.
//  Local overrides persist across launches (DEBUG builds only).
//

import SwiftUI

struct DebugMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(FeatureFlagsProvider.self) private var featureFlags
    @State private var isRefreshing = false
    @State private var lastFetched: Date? = nil

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Info
                Section {
                    Text("Toggles here set **local overrides** that take precedence over API values. Orange dot = override active. Overrides persist across launches.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // MARK: Actions
                Section("Actions") {
                    Button {
                        Task {
                            isRefreshing = true
                            await featureFlags.forceRefresh()
                            lastFetched = await featureFlags.lastFetchedDate()
                            isRefreshing = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Reload Flags Now")
                            Spacer()
                            if isRefreshing { ProgressView() }
                        }
                    }
                    .disabled(isRefreshing)

                    Button(role: .destructive) {
                        featureFlags.clearAllOverrides()
                    } label: {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Clear All Overrides")
                        }
                    }
                }

                // MARK: settings.personalization
                Section("settings.personalization") {
                    flagRow("appIconPicker",
                            key: "settings.personalization.appIconPicker",
                            current: featureFlags.settings.appIconPicker)
                    flagRow("activities",
                            key: "settings.personalization.activities",
                            current: featureFlags.settings.activities)
                    flagRow("protectionMethods",
                            key: "settings.personalization.protectionMethods",
                            current: featureFlags.settings.protectionMethods)
                    flagRow("positions",
                            key: "settings.personalization.positions",
                            current: featureFlags.settings.positions)
                    flagRow("security",
                            key: "settings.personalization.security",
                            current: featureFlags.settings.security)
                    flagRow("  appIconPicker.spicyIcons",
                            key: "settings.personalization.appIconPicker.spicyIcons",
                            current: featureFlags.settings.appIconPickerFlags.spicyIcons)
                }

                // MARK: settings.data
                Section("settings.data") {
                    flagRow("importExport",
                            key: "settings.data.importExport",
                            current: featureFlags.settings.data.importExport)
                    flagRow("deleteData",
                            key: "settings.data.deleteData",
                            current: featureFlags.settings.data.deleteData)
                    flagRow("  importExport.csvImportPartners",
                            key: "settings.data.importExport.csvImportPartners",
                            current: featureFlags.settings.data.importExportFlags.csvImportPartners)
                    flagRow("  importExport.csvImportEncounters",
                            key: "settings.data.importExport.csvImportEncounters",
                            current: featureFlags.settings.data.importExportFlags.csvImportEncounters)
                    flagRow("  importExport.csvExportPartners",
                            key: "settings.data.importExport.csvExportPartners",
                            current: featureFlags.settings.data.importExportFlags.csvExportPartners)
                    flagRow("  importExport.csvExportEncounters",
                            key: "settings.data.importExport.csvExportEncounters",
                            current: featureFlags.settings.data.importExportFlags.csvExportEncounters)
                    flagRow("  importExport.importDatabase",
                            key: "settings.data.importExport.importDatabase",
                            current: featureFlags.settings.data.importExportFlags.importDatabase)
                    flagRow("  importExport.exportDatabase",
                            key: "settings.data.importExport.exportDatabase",
                            current: featureFlags.settings.data.importExportFlags.exportDatabase)
                }

                // MARK: settings.more
                Section("settings.more") {
                    flagRow("about",
                            key: "settings.more.about",
                            current: featureFlags.settings.more.about)
                    flagRow("supportApp",
                            key: "settings.more.supportApp",
                            current: featureFlags.settings.more.supportApp)
                    flagRow("experiments",
                            key: "settings.more.experiments",
                            current: featureFlags.settings.more.experiments)
                    flagRow("debugMenu",
                            key: "settings.more.debugMenu",
                            current: featureFlags.settings.more.debugMenu)
                }

                // MARK: App Info
                Section("App Info") {
                    LabeledContent("Version", value: appVersion())
                    LabeledContent("Last Fetched", value: lastFetched.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                    Button(role: .destructive) {
                        Task { await featureFlags.clearFlagCache() }
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear Flag Cache")
                        }
                    }
                }
            }
            .navigationTitle("Debug Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("Close", systemImage: "xmark") }
                }
            }
            .task {
                lastFetched = await featureFlags.lastFetchedDate()
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func flagRow(_ label: String, key: String, current: Bool) -> some View {
        let isOverridden = featureFlags.overrides[key] != nil
        let binding = Binding<Bool>(
            get: { current },
            set: { newValue in featureFlags.setOverrideRaw(key, value: newValue) }
        )
        return DebugFlagRow(label: label, value: binding, isOverridden: isOverridden)
    }

    private func appVersion() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    DebugMenuView()
        .environment(FeatureFlagsProvider())
}
