//
//  ActivityFormView.swift
//  Fuckify
//
//  Unified form for creating or editing activities
//

import SwiftUI

enum CustomizationFormError: LocalizedError {
    case duplicateName(String)

    var errorDescription: String? {
        switch self {
        case .duplicateName(let message):
            return message
        }
    }
}

struct ActivityFormView: View {
    let existingActivity: SQLActivityTypeEntity?
    let onSave: () -> Void
    
    init(activity: SQLActivityTypeEntity? = nil, onSave: @escaping () -> Void) {
        self.existingActivity = activity
        self.onSave = onSave
    }
    
    var isEditing: Bool {
        existingActivity != nil
    }
    
    var isBuiltIn: Bool {
        existingActivity?.isBuiltIn ?? false
    }

    var body: some View {
        CustomizationItemFormView(
            itemType: "Activity",
            defaultIcon: "heart.fill",
            accentColor: .purple,
            existingName: existingActivity?.name,
            existingIcon: existingActivity?.icon,
            isBuiltIn: isBuiltIn
        ) { name, icon in
            try saveActivity(name: name, icon: icon)
        }
    }

    private func saveActivity(name: String, icon: String) throws {
        let customizationService = CustomizationService()

        if let existing = existingActivity {
            var updated = existing
            updated.name = name
            updated.icon = icon
            try customizationService.updateActivityType(updated)
        } else {
            let existing = (try? customizationService.fetchAllActivityTypes()) ?? []
            if existing.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                throw CustomizationFormError.duplicateName("An activity with this name already exists")
            }

            _ = try customizationService.createActivityType(name: name, icon: icon)
        }

        onSave()
    }
}

// MARK: - Legacy wrappers for backwards compatibility

typealias AddActivityView = ActivityFormView

struct EditActivityView: View {
    let activity: SQLActivityTypeEntity
    let onSave: () -> Void
    
    var body: some View {
        ActivityFormView(activity: activity, onSave: onSave)
    }
}

#Preview("Add Activity") {
    ActivityFormView {
        print("Saved!")
    }
}

#Preview("Edit Activity") {
    let activity = SQLActivityTypeEntity(
        id: UUID(),
        name: "Kissing",
        icon: "heart.fill",
        isBuiltIn: false,
        isEnabled: true,
        sortOrder: 1,
        dateAdded: Date()
    )
    
    return ActivityFormView(activity: activity) {
        print("Saved!")
    }
}
