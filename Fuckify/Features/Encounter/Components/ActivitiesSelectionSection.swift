//
//  ActivitiesSelectionSection.swift
//  Fuckify
//
//  Reusable activities selection section for encounter forms
//

import SwiftUI
import SQLiteData

struct ActivitiesSelectionSection: View {
    let availableActivities: [SQLActivityTypeEntity]
    @Binding var selectedActivityIDs: Set<UUID>
    
    var body: some View {
        Section("Activities") {
            ForEach(availableActivities.filter { $0.isEnabled }) { activity in
                Button(action: { toggleActivity(activity.id) }) {
                    HStack {
                        Image(systemName: activity.icon)
                            .foregroundColor(.purple)
                            .accessibilityHidden(true)
                        Text(activity.name)
                            .foregroundColor(.primary)
                        Spacer()
                        if selectedActivityIDs.contains(activity.id) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityLabel(activity.name)
                .accessibilityAddTraits(selectedActivityIDs.contains(activity.id) ? .isSelected : [])
                .accessibilityHint("Double tap to \(selectedActivityIDs.contains(activity.id) ? "deselect" : "select") this activity")
            }
        }
    }
    
    private func toggleActivity(_ activityID: UUID) {
        if selectedActivityIDs.contains(activityID) {
            selectedActivityIDs.remove(activityID)
        } else {
            selectedActivityIDs.insert(activityID)
        }
    }
}

#Preview {
    let activities = [
        SQLActivityTypeEntity(id: UUID(), name: "Oral", icon: "mouth", isBuiltIn: true),
        SQLActivityTypeEntity(id: UUID(), name: "Kissing", icon: "face.smiling", isBuiltIn: true)
    ]
    
    return Form {
        ActivitiesSelectionSection(
            availableActivities: activities,
            selectedActivityIDs: .constant([activities[0].id])
        )
    }
}
