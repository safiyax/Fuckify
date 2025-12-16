//
//  PartnerFormView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnerFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var partner: Partner?

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var phoneNumber: String = ""
    @State private var isOnPrep: Bool = false
    @State private var relationshipType: RelationshipType = .casual
    @State private var dateMet: Date?
    @State private var showDateMetPicker: Bool = false

    var isEditing: Bool {
        partner != nil
    }

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

                Section("Relationship") {
                    Picker("Relationship Type", selection: $relationshipType) {
                        ForEach([RelationshipType.casual, .regular, .committed, .oneTime, .other], id: \.self) { type in
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

                Section("Health") {
                    Toggle("On PrEP", isOn: $isOnPrep)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(isEditing ? "Edit Partner" : "Add Partner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePartner()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let partner = partner {
                    loadPartner(partner)
                }
            }
        }
    }

    private func loadPartner(_ partner: Partner) {
        name = partner.name
        notes = partner.notes
        phoneNumber = partner.phoneNumber
        isOnPrep = partner.isOnPrep
        relationshipType = partner.relationshipType
        dateMet = partner.dateMet
        showDateMetPicker = partner.dateMet != nil
    }

    private func savePartner() {
        if let partner = partner {
            // Edit existing partner
            partner.name = name
            partner.notes = notes
            partner.phoneNumber = phoneNumber
            partner.isOnPrep = isOnPrep
            partner.relationshipType = relationshipType
            partner.dateMet = showDateMetPicker ? dateMet : nil
        } else {
            // Create new partner
            let newPartner = Partner(
                name: name,
                notes: notes,
                phoneNumber: phoneNumber,
                isOnPrep: isOnPrep,
                relationshipType: relationshipType,
                dateMet: showDateMetPicker ? dateMet : nil
            )
            modelContext.insert(newPartner)
        }

        dismiss()
    }
}

#Preview("Add Partner") {
    PartnerFormView()
        .modelContainer(for: Partner.self, inMemory: true)
}

#Preview("Edit Partner") {
    let container = try! ModelContainer(for: Partner.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let partner = Partner(name: "John Doe", isOnPrep: true, relationshipType: .regular)
    container.mainContext.insert(partner)

    return PartnerFormView(partner: partner)
        .modelContainer(container)
}
