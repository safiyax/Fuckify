//
//  PartnerFormView.swift
//  Fuckify
//
//  Partner form using SQLite services
//

import SwiftUI
import SQLiteData
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnerFormView")

struct PartnerFormView: View {
    @Dependency(\.partnerService) var partnerService
    @Dependency(\.partnerAttributeService) var attributeService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var phoneNumber: String = ""
    @State private var relationshipType: SQLRelationshipType = .casual
    @State private var dateMet: Date?
    @State private var showDateMetPicker: Bool = false
    @State private var avatarColor: String = ""
    @State private var isPinned: Bool = false
    @State private var errorMessage: String?
    
    // Custom attributes
    @State private var enabledAttributes: [SQLPartnerAttributeType] = []
    @State private var attributeValues: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    TextField("Phone Number", text: $phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Avatar Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(PartnerColors.allColorNames, id: \.self) { colorName in
                            Button(action: { avatarColor = colorName }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.fromPartnerColorName(colorName))
                                        .frame(width: 50, height: 50)

                                    if avatarColor == colorName {
                                        Image(systemName: "checkmark")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(colorName.capitalized)
                            .accessibilityAddTraits(avatarColor == colorName ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Relationship") {
                    Picker("Relationship Type", selection: $relationshipType) {
                        ForEach([SQLRelationshipType.casual, .regular, .committed, .oneTime, .other], id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    Toggle("Date Met", isOn: $showDateMetPicker)

                    if showDateMetPicker {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { dateMet ?? Date() },
                                set: { dateMet = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }

                Section("Display") {
                    Toggle("Pinned", isOn: $isPinned)
                        .accessibilityHint("Pin this partner to the top of your partners list")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                // Custom Attributes
                if !enabledAttributes.isEmpty {
                    Section("Additional Information") {
                        ForEach(enabledAttributes, id: \.id) { attribute in
                            PartnerAttributeEditField(
                                attribute: attribute,
                                value: Binding(
                                    get: { attributeValues[attribute.id] },
                                    set: { newValue in
                                        if let newValue {
                                            attributeValues[attribute.id] = newValue
                                        } else {
                                            attributeValues[attribute.id] = nil
                                        }
                                    }
                                )
                            )
                        }
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
            .navigationTitle("Add Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await savePartner()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .task {
                await loadEnabledAttributes()
            }
            .onAppear {
                // Set a default color for new partners
                avatarColor = PartnerColors.randomColorName()
            }
            .dismissOnAppLock()
        }
    }



    private func loadEnabledAttributes() async {
        let service = attributeService
        
        do {
            let attrs = try await Task.detached {
                try await service.fetchEnabledAttributeTypes()
            }.value
            
            enabledAttributes = attrs
        } catch {
            logger.error("Failed to load custom attributes: \(error)")
        }
    }
    
    private func savePartner() async {
        errorMessage = nil
        
        // Create partner draft
        let partnerId = UUID()
        let draft = SQLPartner.Draft(
            id: partnerId,
            name: name.trimmingCharacters(in: .whitespaces),
            notes: notes,
            phoneNumber: phoneNumber,
            relationshipType: relationshipType,
            dateMet: showDateMetPicker ? dateMet : nil,
            avatarColor: avatarColor.isEmpty ? PartnerColors.randomColorName() : avatarColor,
            dateAdded: Date(),
            lastEncounterDate: nil,
            isPinned: isPinned
        )
        
        do {
            // Capture services before detached task to avoid actor isolation issues
            let partnerSvc = partnerService
            let attrSvc = attributeService
            
            // Perform database I/O off main thread
            let _ = try await Task.detached {
                try await partnerSvc.create(draft)
            }.value
            
            // Save custom attribute values
            for (attributeTypeId, value) in attributeValues {
                guard !value.isEmpty else { continue }
                
                do {
                    try await Task.detached {
                        try await attrSvc.setValue(
                            forPartner: partnerId,
                            attributeTypeId: attributeTypeId,
                            value: value
                        )
                    }.value
                } catch {
                    logger.error("Failed to save custom attribute \(attributeTypeId): \(error)")
                }
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save partner. Please try again."
        }
    }
    
}

#Preview("Add Partner") {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return PartnerFormView()
}
