//
//  ActivitiesSettingsView.swift
//  Fuckify
//
//  Settings view for managing activity types
//

import SwiftUI

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
