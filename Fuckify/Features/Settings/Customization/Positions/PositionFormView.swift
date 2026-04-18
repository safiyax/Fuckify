//
//  PositionFormView.swift
//  Fuckify
//

import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PositionForm")

struct PositionFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var errorMessage: String?

    let existingPosition: SQLPositionType?
    let onSave: () -> Void

    init(position: SQLPositionType? = nil, onSave: @escaping () -> Void) {
        self.existingPosition = position
        self.onSave = onSave
        _name = State(initialValue: position?.name ?? "")
        _selectedIcon = State(initialValue: position?.icon ?? "figure.stand")
    }

    var isEditing: Bool { existingPosition != nil }
    var isBuiltIn: Bool { existingPosition?.isBuiltIn ?? false }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Position Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if isBuiltIn {
                        Text("Built-in positions cannot be renamed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Icon") {
                    IconPickerRow(
                        selectedIcon: $selectedIcon,
                        accentColor: .orange,
                        isDisabled: isBuiltIn,
                        onTap: { showingIconPicker = true }
                    )

                    if isBuiltIn {
                        Text("Built-in position icons cannot be changed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Position" : "Add Position")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { errorMessage = "Please enter a name"; return }

        let service = PositionTypeService()
        do {
            if let existing = existingPosition {
                if isBuiltIn { dismiss(); return }
                var updated = existing
                updated.name = trimmed
                updated.icon = selectedIcon
                try service.update(updated)
            } else {
                _ = try service.create(name: trimmed, icon: selectedIcon)
            }
            logger.info("\(isEditing ? "Updated" : "Created") position type")
            onSave()
            dismiss()
        } catch {
            logger.error("Failed to save position: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
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
