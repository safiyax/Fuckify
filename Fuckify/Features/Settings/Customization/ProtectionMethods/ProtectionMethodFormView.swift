//
//  ProtectionMethodFormView.swift
//  Fuckify
//
//  Unified form for creating or editing protection methods
//

import SwiftUI

struct ProtectionMethodFormView: View {
    let existingMethod: SQLProtectionMethodEntity?
    let onSave: () -> Void
    
    init(method: SQLProtectionMethodEntity? = nil, onSave: @escaping () -> Void) {
        self.existingMethod = method
        self.onSave = onSave
    }
    
    var isEditing: Bool {
        existingMethod != nil
    }
    
    var isBuiltIn: Bool {
        existingMethod?.isBuiltIn ?? false
    }

    var body: some View {
        CustomizationItemFormView(
            itemType: "Protection Method",
            defaultIcon: "shield.fill",
            accentColor: .green,
            existingName: existingMethod?.name,
            existingIcon: existingMethod?.icon,
            isBuiltIn: isBuiltIn
        ) { name, icon in
            try saveMethod(name: name, icon: icon)
        }
    }

    private func saveMethod(name: String, icon: String) throws {
        let customizationService = CustomizationService()

        if let existing = existingMethod {
            var updated = existing
            updated.name = name
            updated.icon = icon
            try customizationService.updateProtectionMethod(updated)
        } else {
            let existing = (try? customizationService.fetchAllProtectionMethods()) ?? []
            if existing.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                throw CustomizationFormError.duplicateName("A protection method with this name already exists")
            }

            _ = try customizationService.createProtectionMethod(name: name, icon: icon)
        }

        onSave()
    }
}

// MARK: - Legacy wrappers for backwards compatibility

typealias AddProtectionMethodView = ProtectionMethodFormView

struct EditProtectionMethodView: View {
    let method: SQLProtectionMethodEntity
    let onSave: () -> Void
    
    var body: some View {
        ProtectionMethodFormView(method: method, onSave: onSave)
    }
}

#Preview("Add Protection Method") {
    ProtectionMethodFormView {
        print("Saved!")
    }
}

#Preview("Edit Protection Method") {
    let method = SQLProtectionMethodEntity(
        id: UUID(),
        name: "Condom",
        icon: "shield.fill",
        isBuiltIn: false,
        isEnabled: true,
        sortOrder: 1,
        dateAdded: Date()
    )
    
    return ProtectionMethodFormView(method: method) {
        print("Saved!")
    }
}
