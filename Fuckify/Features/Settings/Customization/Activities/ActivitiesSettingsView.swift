//
//  ActivitiesSettingsView.swift
//  Fuckify
//
//  Settings view for managing activity types
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "ActivitiesSettings")

extension SQLActivityTypeEntity: CustomizableItem {}

struct ActivitiesSettingsView: View {
    @Environment(UserSettings.self) private var settings
    @State private var activities: [SQLActivityTypeEntity] = []
    
    private let accentColor = Color.purple
    
    var body: some View {
        CustomizationSettingsView(
            navigationTitle: "Activities",
            itemTypeName: "Activity",
            descriptionText: "Manage activities for logging encounters. Built-in activities can be enabled/disabled. Custom activities can be edited or deleted.",
            accentColor: accentColor,
            items: activities,
            onToggle: toggleActivity,
            onDelete: deleteActivity,
            addSheet: { ActivityFormView(onSave: loadActivities) },
            editSheet: { activity in
                ActivityFormView(activity: activity, onSave: loadActivities)
            },
            itemRow: { activity, toggle in
                ActivityRow(activity: activity, onToggle: toggle)
            }
        )
        .onAppear { loadActivities() }
    }
    
    private func loadActivities() {
        activities = settings.allActivityTypes()
    }
    
    private func toggleActivity(_ activity: SQLActivityTypeEntity) {
        logger.info("Toggling activity: \(activity.id)")
        settings.toggleActivity(activity.id)
        loadActivities()
    }
    
    private func deleteActivity(_ activity: SQLActivityTypeEntity) {
        logger.info("Deleting activity: \(activity.id)")
        settings.deleteActivity(activity.id)
        loadActivities()
    }
}

// MARK: - Activity Row

private struct ActivityRow: View {
    let activity: SQLActivityTypeEntity
    let onToggle: () -> Void

    var body: some View {
        CustomizationItemRow(
            icon: activity.icon,
            name: activity.name,
            isEnabled: activity.isEnabled,
            isBuiltIn: activity.isBuiltIn,
            accentColor: .purple,
            onToggle: onToggle
        )
    }
}
