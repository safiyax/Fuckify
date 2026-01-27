//
//  SettingsView.swift
//  Fuckify
//
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Customize which activities and protection methods appear when logging encounters.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section("Personalization") {
                    NavigationLink {
                        AppIconSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "app.fill")
                                .foregroundColor(.pink)
                            Text("App Icon")
                        }
                    }

                    NavigationLink {
                        ActivitiesSettingsView()
                    } label: {
                        HStack {
                            Image(systemName: "heart.circle.fill")
                                .foregroundColor(.purple)
                            Text("Activities")
                        }
                    }

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

                Section("Data") {
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

                Section("More") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("About")
                        }
                    }
                    NavigationLink {
//                        CalendarView()
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
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Label("Close", systemImage: "xmark")
                    }
                    
                }
            }
        }
    }
}

// MARK: - Activities Settings View

struct ActivitiesSettingsView: View {
    @State private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section {
                Text("Toggle which activities appear when logging encounters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(SQLActivityType.allCases, id: \.self) { activity in
                    Toggle(isOn: Binding(
                        get: { settings.isActivityEnabled(activity) },
                        set: { _ in settings.toggleActivity(activity) }
                    )) {
                        HStack {
                            Image(systemName: activity.icon)
                                .foregroundColor(.purple)
                            Text(activity.displayName)
                        }
                    }
                }
            }

            Section {
                Button("Enable All") {
                    settings.enabledActivities = Set(SQLActivityType.allCases)
                }
            }
        }
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Protection Methods Settings View

struct ProtectionMethodsSettingsView: View {
    @State private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section {
                Text("Toggle which protection methods appear when logging encounters.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Section {
                ForEach(SQLProtectionMethod.allCases, id: \.self) { method in
                    Toggle(isOn: Binding(
                        get: { settings.isProtectionMethodEnabled(method) },
                        set: { _ in settings.toggleProtectionMethod(method) }
                    )) {
                        HStack {
                            Image(systemName: method.icon)
                                .foregroundColor(.green)
                            Text(method.displayName)
                        }
                    }
                }
            }

            Section {
                Button("Enable All") {
                    settings.enabledProtectionMethods = Set(SQLProtectionMethod.allCases)
                }
            }
        }
        .navigationTitle("Protection Methods")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
}
