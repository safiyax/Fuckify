//
//  PositionFormView.swift
//  Fuckify
//

import SwiftUI

struct PositionFormView: View {
    let existingPosition: SQLPositionType?
    let onSave: () -> Void

    init(position: SQLPositionType? = nil, onSave: @escaping () -> Void) {
        self.existingPosition = position
        self.onSave = onSave
    }

    var isEditing: Bool { existingPosition != nil }
    var isBuiltIn: Bool { existingPosition?.isBuiltIn ?? false }

    var body: some View {
        CustomizationItemFormView(
            itemType: "Position",
            defaultIcon: "figure.stand",
            accentColor: .orange,
            existingName: existingPosition?.name,
            existingIcon: existingPosition?.icon,
            isBuiltIn: isBuiltIn
        ) { name, icon in
            try save(name: name, icon: icon)
        }
    }

    private func save(name: String, icon: String) throws {
        let service = PositionTypeService()

        if let existing = existingPosition {
            var updated = existing
            updated.name = name
            updated.icon = icon
            try service.update(updated)
        } else {
            _ = try service.create(name: name, icon: icon)
        }

        onSave()
    }
}

#Preview("Add Position") {
    PositionFormView {
        print("Saved!")
    }
}

#Preview("Edit Position") {
    let position = SQLPositionType(
        id: UUID(),
        name: "Missionary",
        icon: "figure.stand",
        isBuiltIn: false,
        isEnabled: true,
        sortOrder: 1,
        dateAdded: Date()
    )
    return PositionFormView(position: position) {
        print("Saved!")
    }
}
