//
//  SettingsView.swift
//  Fuckify
//
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = true
    private let config = SettingsConfig.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Customize which activities and protection methods appear when logging encounters.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if config.showPersonalizationSection {
                    Section("Personalization") {
                        if config.showAppIconPicker {
                            NavigationLink {
                                AppIconSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "app.fill")
                                        .foregroundColor(.pink)
                                    Text("App Icon")
                                }
                            }
                        }

                        if config.showActivities {
                            NavigationLink {
                                ActivitiesSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                        .foregroundColor(.purple)
                                    Text("Activities")
                                }
                            }
                        }

                        if config.showProtectionMethods {
                            NavigationLink {
                                ProtectionMethodsSettingsView()
                            } label: {
                                HStack {
                                    Image(systemName: "shield.fill")
                                        .foregroundColor(.green)
                                    Text("Protection Methods")
                                }
                            }
                        }
                        
                        if config.showSecurity {
                            NavigationLink {
                                SecurityView()
                            } label: {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.orange)
                                    Text("Security")
                                }
                            }
                        }
                    }
                }

                if config.showDataSection {
                    Section("Data") {
                        if config.showImportExport {
                            NavigationLink {
                                ImportView()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .foregroundColor(.blue)
                                    Text("Import & Export")
                                        .foregroundColor(.primary)
                                }
                            }
                        }

                        if config.showDeleteData {
                            NavigationLink {
                                DeleteDataView()
                            } label: {
                                HStack {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.red)
                                    Text("Delete Data")
                                }
                            }
                        }
                    }
                }

                if config.showMoreSection {
                    Section("More") {
                        if config.showAbout {
                            NavigationLink {
                                AboutView()
                            } label: {
                                HStack {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("About")
                                }
                            }
                        }
                        
                        if config.showSupport {
                            NavigationLink {
                                SupportView()
                            } label: {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.pink)
                                    Text("Support the App")
                                }
                            }
                        }
                        
                        if config.showExperiments {
                            NavigationLink {
                                ContentUnavailableView("Nothing to see here.", systemImage: "hourglass")
                                    .navigationTitle("Experiments")

                            } label: {
                                HStack {
                                    Image(systemName: "gear.badge.questionmark")
                                        .foregroundColor(.green)
                                    Text("Experiments")
                                }
                            }
                        }
                        
                        // Reset onboarding button
                        Button {
                            hasCompletedOnboarding = false
                        } label: {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .foregroundColor(.purple)
                                Text("View Onboarding")
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Close", systemImage: "xmark")
                    }
                    
                }
            }
            .dismissOnAppLock()
        }
    }
}

// MARK: - Activities Settings View

/// Sheet presentation mode for activity form
enum ActivityFormMode: Identifiable {
    case add
    case edit(activity: SQLActivityTypeEntity)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let activity): return "edit-\(activity.id)"
        }
    }
}

struct ActivitiesSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var activities: [SQLActivityTypeEntity] = []
    @State private var activityFormMode: ActivityFormMode?

    var body: some View {
        Form {
            Section {
                Text("Toggle which activities appear when logging encounters. Tap to edit custom activities.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(activities) { activity in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { activity.isEnabled },
                            set: { _ in
                                settings.toggleActivity(activity.id)
                                loadActivities()
                            }
                        )) {
                            HStack {
                                Image(systemName: activity.icon)
                                    .foregroundColor(.purple)
                                    .frame(width: 24)
                                Text(activity.name)
                                
                                if activity.isBuiltIn {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Only allow editing custom activities
                        if !activity.isBuiltIn {
                            Button {
                                activityFormMode = .edit(activity: activity)
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button {
                    activityFormMode = .add
                } label: {
                    Label("Add Custom Activity", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadActivities()
        }
        .sheet(item: $activityFormMode) { mode in
            switch mode {
            case .add:
                AddActivityView(onSave: {
                    loadActivities()
                })
            case .edit(let activity):
                EditActivityView(activity: activity, onSave: {
                    loadActivities()
                })
            }
        }
    }
    
    private func loadActivities() {
        activities = settings.allActivityTypes()
    }
}

// MARK: - Protection Methods Settings View

/// Sheet presentation mode for protection method form
enum ProtectionMethodFormMode: Identifiable {
    case add
    case edit(method: SQLProtectionMethodEntity)
    
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let method): return "edit-\(method.id)"
        }
    }
}

struct ProtectionMethodsSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var protectionMethods: [SQLProtectionMethodEntity] = []
    @State private var methodFormMode: ProtectionMethodFormMode?

    var body: some View {
        Form {
            Section {
                Text("Toggle which protection methods appear when logging encounters. Tap to edit custom methods.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(protectionMethods) { method in
                    HStack {
                        Toggle(isOn: Binding(
                            get: { method.isEnabled },
                            set: { _ in
                                settings.toggleProtectionMethod(method.id)
                                loadProtectionMethods()
                            }
                        )) {
                            HStack {
                                Image(systemName: method.icon)
                                    .foregroundColor(.green)
                                    .frame(width: 24)
                                Text(method.name)
                                
                                if method.isBuiltIn {
                                    Spacer()
                                    Image(systemName: "lock.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Only allow editing custom methods
                        if !method.isBuiltIn {
                            Button {
                                methodFormMode = .edit(method: method)
                            } label: {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button {
                    methodFormMode = .add
                } label: {
                    Label("Add Custom Protection Method", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("Protection Methods")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadProtectionMethods()
        }
        .sheet(item: $methodFormMode) { mode in
            switch mode {
            case .add:
                AddProtectionMethodView(onSave: {
                    loadProtectionMethods()
                })
            case .edit(let method):
                EditProtectionMethodView(method: method, onSave: {
                    loadProtectionMethods()
                })
            }
        }
    }
    
    private func loadProtectionMethods() {
        protectionMethods = settings.allProtectionMethods()
    }
}

#Preview {
    SettingsView()
}
