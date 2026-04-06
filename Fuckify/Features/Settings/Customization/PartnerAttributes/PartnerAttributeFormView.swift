//
//  PartnerAttributeFormView.swift
//  Fuckify
//
//  Form to create or edit a custom partner attribute
//

import SwiftUI
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnerAttributeForm")

struct PartnerAttributeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.partnerAttributeService) private var attributeService
    
    @State private var name: String
    @State private var selectedFieldType: PartnerAttributeFieldType
    @State private var selectedIcon: String
    @State private var enumChoices: [String]
    @State private var showingIconPicker = false
    @State private var errorMessage: String?
    
    let existingAttribute: SQLPartnerAttributeType?
    let onSave: () -> Void
    
    init(attribute: SQLPartnerAttributeType? = nil, onSave: @escaping () -> Void) {
        self.existingAttribute = attribute
        self.onSave = onSave
        
        // Initialize state based on whether we're editing or creating
        if let attribute = attribute {
            _name = State(initialValue: attribute.name)
            _selectedFieldType = State(initialValue: attribute.parsedFieldType)
            _selectedIcon = State(initialValue: attribute.icon)
            _enumChoices = State(initialValue: attribute.parsedEnumChoices)
        } else {
            _name = State(initialValue: "")
            _selectedFieldType = State(initialValue: .text)
            _selectedIcon = State(initialValue: "person.text.rectangle")
            _enumChoices = State(initialValue: [])
        }
    }
    
    var isEditing: Bool {
        existingAttribute != nil
    }
    
    var isBuiltIn: Bool {
        existingAttribute?.isBuiltIn ?? false
    }
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (selectedFieldType != .enumType || !enumChoices.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Attribute Name", text: $name)
                        .autocapitalization(.words)
                        .disabled(isBuiltIn)
                } footer: {
                    if !isBuiltIn {
                        Text("e.g., \"Last Test Date\", \"Vaccination Status\", \"Relationship Goal\"")
                            .font(.caption)
                    } else {
                        Text("Built-in attributes cannot be renamed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Picker("Field Type", selection: $selectedFieldType) {
                        ForEach(PartnerAttributeFieldType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .disabled(isEditing) // Can't change field type when editing
                    
                    // Help text for each type
                    switch selectedFieldType {
                    case .text:
                        Text("Free-form text input")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .boolean:
                        Text("Yes/No toggle switch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .date:
                        Text("Date picker")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .enumType:
                        Text("Multiple choice picker")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    if isEditing {
                        Text("Field type cannot be changed after creation")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Enum choices (only shown for enum type)
                if selectedFieldType == .enumType {
                    Section {
                        if isBuiltIn {
                            // Built-in: show choices as read-only
                            ForEach(enumChoices.indices, id: \.self) { index in
                                TextField("Choice", text: $enumChoices[index])
                                    .autocapitalization(.words)
                                    .disabled(true)
                            }
                        } else {
                            // Custom: allow editing
                            ForEach(enumChoices.indices, id: \.self) { index in
                                HStack {
                                    TextField("Choice", text: $enumChoices[index])
                                        .autocapitalization(.words)
                                    
                                    Button {
                                        removeChoice(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .onMove(perform: moveChoices)
                            .onDelete(perform: deleteChoices)
                            
                            Button(action: addChoice) {
                                Label("Add Choice", systemImage: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    } header: {
                        Text("Choices")
                    } footer: {
                        if !isBuiltIn {
                            Text("Tap + to add, swipe to delete, or drag to reorder.")
                                .font(.caption)
                        } else {
                            Text("Built-in attribute choices cannot be modified")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("Icon") {
                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundColor(.accentColor)
                                .frame(width: 40, height: 40)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                            
                            Text("Choose Icon")
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(isBuiltIn)
                    .accessibilityLabel("Choose icon for attribute")
                    
                    if isBuiltIn {
                        Text("Built-in attribute icons cannot be changed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Attribute" : "Add Custom Attribute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button("Save") {
                        saveAttribute()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                SFSymbolPickerView(selectedIcon: $selectedIcon)
            }
        }
    }
    
    private func addChoice() {
        withAnimation {
            enumChoices.append("")
        }
    }
    
    private func removeChoice(at index: Int) {
        _ = withAnimation {
            enumChoices.remove(at: index)
        }
    }
    
    private func moveChoices(from source: IndexSet, to destination: Int) {
        enumChoices.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deleteChoices(at offsets: IndexSet) {
        enumChoices.remove(atOffsets: offsets)
    }
    
    private func saveAttribute() {
        errorMessage = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Parse enum choices if applicable
        var choicesForSave: [String]? = nil
        if selectedFieldType == .enumType {
            let choices = enumChoices
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard !choices.isEmpty else {
                errorMessage = "Please provide at least one choice for the multiple choice field"
                return
            }
            
            choicesForSave = choices
        }
        
        do {
            if let existing = existingAttribute {
                // Update existing attribute
                var updated = existing
                
                // Only allow updating certain fields for built-in attributes
                if isBuiltIn {
                    // Built-in: only icon can be updated (name, type, choices locked)
                    // Actually, for built-in we disabled icon too, so nothing to update
                    // Just dismiss
                } else {
                    // Custom: can update name, icon, enum choices
                    updated.name = trimmedName
                    updated.icon = selectedIcon
                    updated.enumChoices = choicesForSave?.toJSONString()
                }
                
                try attributeService.updateAttributeType(updated)
            } else {
                // Create new attribute
                _ = try attributeService.createAttributeType(
                    name: trimmedName,
                    fieldType: selectedFieldType,
                    icon: selectedIcon,
                    enumChoices: choicesForSave,
                    isEnabled: true
                )
            }
            
            logger.info("\(isEditing ? "Updated" : "Created") partner attribute type")
            onSave()
            dismiss()
        } catch {
            logger.error("Failed to save partner attribute type: \(error.localizedDescription)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Legacy wrapper for backwards compatibility

typealias AddPartnerAttributeView = PartnerAttributeFormView

#Preview("Add New Attribute") {
    PartnerAttributeFormView {
        print("Saved!")
    }
}

#Preview("Edit Existing Attribute") {
    let attribute = SQLPartnerAttributeType(
        id: UUID(),
        name: "HIV Status",
        fieldType: .enumType,
        icon: "cross.fill",
        isBuiltIn: true,
        isEnabled: true,
        sortOrder: 1,
        dateAdded: Date(),
        enumChoices: ["Negative", "Positive", "Unknown"]
    )
    
    return PartnerAttributeFormView(attribute: attribute) {
        print("Saved!")
    }
}
