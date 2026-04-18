import SwiftUI

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "CustomizationItemForm")

/// The shared form body used by ActivityFormView, ProtectionMethodFormView, and PositionFormView.
///
/// - Parameters:
///   - itemType: Human-readable noun used in titles and error messages (e.g. "Activity").
///   - defaultIcon: The SF Symbol name to use when creating a new item.
///   - accentColor: Tint color applied to the icon picker and other accent elements.
///   - existingName: Pre-filled name when editing; nil when creating.
///   - existingIcon: Pre-filled icon when editing; nil when creating.
///   - isBuiltIn: When true, name and icon fields are read-only.
///   - onSave: Called with (name, icon) when the form is submitted.
struct CustomizationItemFormView: View {
    @Environment(\.dismiss) private var dismiss

    let itemType: String
    let defaultIcon: String
    let accentColor: Color
    let isEditing: Bool
    let isBuiltIn: Bool
    let onSave: (String, String) throws -> Void

    @State private var name: String
    @State private var selectedIcon: String
    @State private var showingIconPicker = false
    @State private var errorMessage: String?

    init(
        itemType: String,
        defaultIcon: String,
        accentColor: Color,
        existingName: String? = nil,
        existingIcon: String? = nil,
        isBuiltIn: Bool = false,
        onSave: @escaping (String, String) throws -> Void
    ) {
        self.itemType = itemType
        self.defaultIcon = defaultIcon
        self.accentColor = accentColor
        self.isEditing = existingName != nil
        self.isBuiltIn = isBuiltIn
        self.onSave = onSave
        _name = State(initialValue: existingName ?? "")
        _selectedIcon = State(initialValue: existingIcon ?? defaultIcon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("\(itemType) Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if isBuiltIn {
                        Text("Built-in \(itemType.lowercased())s cannot be renamed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Icon") {
                    IconPickerRow(
                        selectedIcon: $selectedIcon,
                        accentColor: accentColor,
                        isDisabled: isBuiltIn,
                        onTap: { showingIconPicker = true }
                    )

                    if isBuiltIn {
                        Text("Built-in \(itemType.lowercased()) icons cannot be changed")
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
            .navigationTitle(isEditing ? "Edit \(itemType)" : "Add \(itemType)")
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
        guard !isBuiltIn else {
            dismiss()
            return
        }

        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a name"
            return
        }

        do {
            try onSave(trimmed, selectedIcon)
            logger.info("\(isEditing ? "Updated" : "Created") \(itemType.lowercased())")
            dismiss()
        } catch {
            logger.error("Failed to save \(itemType.lowercased()): \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
