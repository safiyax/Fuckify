//
//  PartnerDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SQLiteData
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnerDetailView")

struct PartnerDetailView: View {
    let partner: SQLPartner
    @Environment(\.editMode) private var editMode
    @State private var showingAddEncounter = false
    @State private var encounters: [SQLEncounter] = []
    @State private var isLoadingEncounters = true
    @State private var currentPartner: SQLPartner
    
    @Dependency(\.partnerService) private var partnerService
    @Dependency(\.encounterService) private var encounterService
    @Dependency(\.partnerAttributeService) private var attributeService

    // Editable fields
    @State private var editName: String = ""
    @State private var editNotes: String = ""
    @State private var editPhoneNumber: String = ""
    @State private var editRelationshipType: SQLRelationshipType = .casual
    @State private var editDateMet: Date?
    @State private var editShowDateMetPicker: Bool = false
    @State private var editAvatarColor: String = ""
    @State private var editIsPinned: Bool = false
    @State private var editDefaultPositionTypeId: UUID? = nil
    @State private var availablePositions: [SQLPositionType] = []

    // Custom attributes
    @State private var attributesWithValues: [PartnerAttributeWithValue] = []
    @State private var editAttributeValues: [UUID: String] = [:]
    
    init(partner: SQLPartner) {
        self.partner = partner
        _currentPartner = State(initialValue: partner)
    }

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        List {
            // Avatar Section
            PartnerAvatarHeader(
                partner: currentPartner,
                isEditing: isEditing,
                editName: editName,
                editAvatarColor: editAvatarColor
            )

            // Basic Information
            if isEditing {
                Section("Basic Information") {
                    TextField("Name", text: $editName)
                        .textContentType(.name)

                    TextField("Phone Number", text: $editPhoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                AvatarColorPickerGrid(selectedColor: $editAvatarColor)
            } else {
                // Contact Information
                Section("Contact") {
                    if !currentPartner.phoneNumber.isEmpty {
                        HStack {
                            Text("Phone")
                            Spacer()
                            Text(currentPartner.phoneNumber)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("No phone number")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Relationship Details
            Section("Relationship") {
                if isEditing {
                    Picker("Relationship Type", selection: $editRelationshipType) {
                        ForEach([SQLRelationshipType.casual, .regular, .committed, .oneTime, .other], id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Toggle("Date Met", isOn: $editShowDateMetPicker)

                    if editShowDateMetPicker {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { editDateMet ?? Date() },
                                set: { editDateMet = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }

                    if !availablePositions.isEmpty {
                        Picker("Default Position", selection: $editDefaultPositionTypeId) {
                            Text("None").tag(UUID?.none)
                            ForEach(availablePositions) { position in
                                Label(position.name, systemImage: position.icon)
                                    .tag(Optional(position.id))
                            }
                        }
                    }
                } else {
                    if let dateMet = currentPartner.dateMet {
                        HStack {
                            Text("Date Met")
                            Spacer()
                            Text(dateMet.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let posId = currentPartner.defaultPositionTypeId,
                       let position = availablePositions.first(where: { $0.id == posId }) {
                        HStack {
                            Text("Default Position")
                            Spacer()
                            Label(position.name, systemImage: position.icon)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Added")
                        Spacer()
                        Text(currentPartner.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }

                    if let lastEncounter = currentPartner.lastEncounterDate {
                        HStack {
                            Text("Last Encounter")
                            Spacer()
                            Text(lastEncounter.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Custom Attributes - only show if at least one attribute has a value
            if !attributesWithValues.isEmpty {
                let attributesWithSetValues = attributesWithValues.filter { $0.value != nil }
                
                if isEditing || !attributesWithSetValues.isEmpty {
                    Section("Additional Information") {
                        ForEach(attributesWithValues, id: \.type.id) { attrWithValue in
                            if isEditing {
                                PartnerAttributeEditField(
                                    attribute: attrWithValue.type,
                                    value: editValueBinding(for: attrWithValue.type)
                                )
                            } else if attrWithValue.value != nil {
                                // Only show in display mode if value is set
                                customAttributeDisplayField(for: attrWithValue)
                            }
                        }
                    }
                }
            }

            // Display Settings
            if isEditing {
                Section("Display") {
                    Toggle("Pinned", isOn: $editIsPinned)
                        .accessibilityHint("Pin this partner to the top of your partners list")
                }
            }

            // Notes
            Section("Notes") {
                if isEditing {
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 100)
                } else if !currentPartner.notes.isEmpty {
                    Text(currentPartner.notes)
                        .foregroundColor(.secondary)
                } else {
                    Text("No notes")
                        .foregroundColor(.secondary)
                }
            }

            // Encounters (only shown when not editing)
            if !isEditing {
                PartnerEncountersList(encounters: encounters)
            }
        }
//        .navigationTitle("Partner Details")
        .navigationBarTitleDisplayMode(.inline)
        .animation(nil, value: editMode?.wrappedValue)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .disabled(isEditing && editName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !isEditing {
                ToolbarItem {
                    Button(action: { showingAddEncounter = true }) {
                        Label("Add Encounter", systemImage: "plus")
                    }
                    .accessibilityHint("Opens form to log a new encounter")
                }
            }
        }
        .sheet(isPresented: $showingAddEncounter) {
            EncounterFormView(preselectedPartners: [partner])
        }
        .onChange(of: showingAddEncounter) { _, isShowing in
            if !isShowing {
                // Sheet was dismissed, reload encounters
                Task {
                    await loadEncounters()
                }
            }
        }
        .task {
            loadEditableFields()
            await loadEncounters()
            await loadCustomAttributes()
            availablePositions = (try? PositionTypeService().fetchAll()) ?? []
        }
        .onChange(of: editMode?.wrappedValue) { oldValue, newValue in
            if oldValue?.isEditing == true && newValue?.isEditing == false {
                // Save changes when exiting edit mode
                Task {
                    await saveChanges()
                    await saveCustomAttributes()
                }
            } else if oldValue?.isEditing == false && newValue?.isEditing == true {
                // Reload fields when entering edit mode
                loadEditableFields()
                loadEditableAttributeValues()
            }
        }
    }

    // MARK: - Functions

    private func loadEditableFields() {
        editName = currentPartner.name
        editNotes = currentPartner.notes
        editPhoneNumber = currentPartner.phoneNumber
        editRelationshipType = currentPartner.relationshipType
        editDateMet = currentPartner.dateMet
        editShowDateMetPicker = currentPartner.dateMet != nil
        editAvatarColor = currentPartner.avatarColor
        editIsPinned = currentPartner.isPinned
        editDefaultPositionTypeId = currentPartner.defaultPositionTypeId
    }
    
    private func loadEditableAttributeValues() {
        editAttributeValues.removeAll()
        for attrWithValue in attributesWithValues {
            if let attributeValue = attrWithValue.value {
                editAttributeValues[attrWithValue.type.id] = attributeValue.value
            }
        }
    }

    private func saveChanges() async {
        var updatedPartner = currentPartner
        updatedPartner.name = editName
        updatedPartner.notes = editNotes
        updatedPartner.phoneNumber = editPhoneNumber
        updatedPartner.relationshipType = editRelationshipType
        updatedPartner.dateMet = editShowDateMetPicker ? editDateMet : nil
        updatedPartner.avatarColor = editAvatarColor
        updatedPartner.isPinned = editIsPinned
        updatedPartner.defaultPositionTypeId = editDefaultPositionTypeId

        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = partnerService
            
            // Perform database I/O off main thread
            try await Task.detached {
                try await service.update(updatedPartner)
            }.value
            
            // Update the current partner to reflect changes with animation
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPartner = updatedPartner
            }
        } catch {
            logger.error("Failed to update partner: \(error)")
        }
    }



    private func loadEncounters() async {
        isLoadingEncounters = true
        
        // Capture service before detached task to avoid actor isolation issues
        let service = encounterService
        
        // Perform database I/O off main thread
        do {
            let allEncounters = try await Task.detached {
                try await service.fetchAll()
            }.value
            
            // Filter encounters that include this partner
            var partnerEncounters: [SQLEncounter] = []
            for encounter in allEncounters {
                do {
                    let partners = try await Task.detached {
                        try await service.fetchPartners(for: encounter.id)
                    }.value
                    if partners.contains(where: { $0.id == partner.id }) {
                        partnerEncounters.append(encounter)
                    }
                } catch {
                    // Skip encounters we can't load partners for
                }
            }
            encounters = partnerEncounters
        } catch {
            logger.error("Failed to load encounters: \(error)")
        }
        
        isLoadingEncounters = false
    }
    
    private func loadCustomAttributes() async {
        let service = attributeService
        
        do {
            let attrs = try await Task.detached {
                try await service.fetchAttributesWithValues(forPartner: currentPartner.id)
            }.value
            
            attributesWithValues = attrs
            loadEditableAttributeValues()
        } catch {
            logger.error("Failed to load custom attributes: \(error)")
        }
    }
    
    private func saveCustomAttributes() async {
        let service = attributeService
        
        for (attributeTypeId, value) in editAttributeValues {
            do {
                try await Task.detached {
                    // If value is empty, delete the record
                    if value.isEmpty {
                        try await service.deleteValue(forPartner: currentPartner.id, attributeTypeId: attributeTypeId)
                    } else {
                        try await service.setValue(
                            forPartner: currentPartner.id,
                            attributeTypeId: attributeTypeId,
                            value: value
                        )
                    }
                }.value
            } catch {
                logger.error("Failed to save custom attribute \(attributeTypeId): \(error)")
            }
        }
        
        // Reload attributes after saving
        await loadCustomAttributes()
    }

    private func editValueBinding(for attribute: SQLPartnerAttributeType) -> Binding<String?> {
        Binding(
            get: { editAttributeValues[attribute.id] },
            set: { newValue in
                if attribute.parsedFieldType == .boolean && newValue == "false" {
                    editAttributeValues[attribute.id] = nil
                } else {
                    editAttributeValues[attribute.id] = newValue
                }
            }
        )
    }
    
    @ViewBuilder
    private func customAttributeDisplayField(for attrWithValue: PartnerAttributeWithValue) -> some View {
        HStack {
            Label(attrWithValue.type.name, systemImage: attrWithValue.type.icon)
            Spacer()
            
            if let attributeValue = attrWithValue.value {
                let valueString = attributeValue.value
                switch attrWithValue.type.parsedFieldType {
                case PartnerAttributeFieldType.text:
                    Text(valueString)
                        .foregroundColor(.secondary)
                case PartnerAttributeFieldType.boolean:
                    if valueString == "true" {
                        Text("Yes")
                            .foregroundColor(.secondary)
                    } else {
                        Text("No")
                            .foregroundColor(.secondary)
                    }
                case PartnerAttributeFieldType.date:
                    if let date = ISO8601DateFormatter().date(from: valueString) {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not set")
                            .foregroundColor(.secondary)
                    }
                case PartnerAttributeFieldType.enumType:
                    Text(valueString)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Not set")
                    .foregroundColor(.secondary)
            }
        }
    }
    
}



#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    let partner = SQLPartner(
        id: UUID(),
        name: "John Doe",
        notes: "Met at the gym, really nice person",
        phoneNumber: "555-0123",
        relationshipType: .regular,
        dateMet: Date().addingTimeInterval(-86400 * 30),
        avatarColor: "blue",
        dateAdded: Date(),
        lastEncounterDate: Date().addingTimeInterval(-86400 * 7),
        isPinned: false
    )

    NavigationStack {
        PartnerDetailView(partner: partner)
    }
}
