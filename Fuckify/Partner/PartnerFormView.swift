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
    @State private var avatarColor: String = ""

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

                Section("Avatar Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "indigo"], id: \.self) { colorName in
                            Button(action: { avatarColor = colorName }) {
                                ZStack {
                                    Circle()
                                        .fill(colorFromName(colorName))
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
                        }
                    }
                    .padding(.vertical, 8)
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
                } else {
                    // Set a default color for new partners
                    avatarColor = Partner.randomColorName()
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
        avatarColor = partner.avatarColor
    }

    private func colorFromName(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green": return .green
        case "teal": return .teal
        case "indigo": return .indigo
        default: return .blue
        }
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
            partner.avatarColor = avatarColor
        } else {
            // Create new partner
            let newPartner = Partner(
                name: name,
                notes: notes,
                phoneNumber: phoneNumber,
                isOnPrep: isOnPrep,
                relationshipType: relationshipType,
                dateMet: showDateMetPicker ? dateMet : nil,
                avatarColor: avatarColor.isEmpty ? nil : avatarColor
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
