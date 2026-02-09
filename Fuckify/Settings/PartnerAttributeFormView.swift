//
//  PartnerAttributeFormView.swift
//  Fuckify
//
//  Form to create or edit a custom partner attribute
//

import SwiftUI
import Dependencies

struct PartnerAttributeFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.partnerAttributeService) private var attributeService
    
    @State private var name: String
    @State private var selectedFieldType: PartnerAttributeFieldType
    @State private var selectedIcon: String
    @State private var enumChoicesText: String
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
            _enumChoicesText = State(initialValue: attribute.parsedEnumChoices.joined(separator: "\n"))
        } else {
            _name = State(initialValue: "")
            _selectedFieldType = State(initialValue: .text)
            _selectedIcon = State(initialValue: "person.text.rectangle")
            _enumChoicesText = State(initialValue: "")
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
        (selectedFieldType != .enumType || !enumChoicesText.isEmpty)
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
                
                Section("Field Type") {
                    Picker("Type", selection: $selectedFieldType) {
                        ForEach(PartnerAttributeFieldType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
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
                    
                    if isEditing {
                        Text("Field type cannot be changed after creation")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                
                // Enum choices (only shown for enum type)
                if selectedFieldType == .enumType {
                    Section {
                        TextEditor(text: $enumChoicesText)
                            .frame(minHeight: 80)
                            .autocapitalization(.words)
                            .disabled(isBuiltIn)
                    } header: {
                        Text("Choices (one per line)")
                    } footer: {
                        if !isBuiltIn {
                            Text("Enter each choice on a separate line. Example:\nNegative\nPositive\nUnknown")
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
                                .foregroundColor(.blue)
                                .frame(width: 40, height: 40)
                                .background(Color.blue.opacity(0.1))
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveAttribute()
                    }
                    .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                PartnerAttributeIconPickerView(selectedIcon: $selectedIcon)
            }
        }
    }
    
    private func saveAttribute() {
        errorMessage = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        
        // Parse enum choices if applicable
        var enumChoices: [String]? = nil
        if selectedFieldType == .enumType {
            let choices = enumChoicesText
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard !choices.isEmpty else {
                errorMessage = "Please provide at least one choice for the multiple choice field"
                return
            }
            
            enumChoices = choices
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
                    updated.enumChoices = enumChoices?.toJSONString()
                }
                
                try attributeService.updateAttributeType(updated)
            } else {
                // Create new attribute
                _ = try attributeService.createAttributeType(
                    name: trimmedName,
                    fieldType: selectedFieldType,
                    icon: selectedIcon,
                    enumChoices: enumChoices,
                    isEnabled: true
                )
            }
            
            onSave()
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - Icon Picker

struct PartnerAttributeIconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    
    // Curated icons relevant to partner attributes
    private let icons = [
        // General
        "person.text.rectangle", "person.crop.circle", "heart.text.square",
        // Medical/Health
        "cross.fill", "pills.fill", "calendar.badge.clock", "stethoscope",
        "medical.thermometer", "syringe", "bandage.fill",
        // Dates/Time
        "calendar", "clock", "hourglass", "timer",
        // Status/Info
        "info.circle", "checkmark.circle", "xmark.circle", "exclamationmark.circle",
        "star.fill", "flag.fill", "bookmark.fill",
        // Communication
        "phone.fill", "message.fill", "envelope.fill",
        // Relationships
        "heart.fill", "heart.circle", "sparkles", "hands.and.sparkles.fill",
        // Other
        "globe", "house.fill", "briefcase.fill", "graduationcap.fill",
        "leaf.fill", "drop.fill", "flame.fill", "bolt.fill", "guidepoint.vertical.numbers"
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(icons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: icon)
                                    .font(.largeTitle)
                                    .foregroundColor(selectedIcon == icon ? .blue : .primary)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(selectedIcon == icon ? Color.blue.opacity(0.1) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2)
                                    )
                            }
                        }
                        .accessibilityLabel(icon.replacingOccurrences(of: ".", with: " "))
                        .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
