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

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var phoneNumber: String = ""
    @State private var isOnPrep: Bool = false
    @State private var relationshipType: RelationshipType = .casual
    @State private var dateMet: Date?
    @State private var showDateMetPicker: Bool = false
    @State private var avatarColor: String = ""
    @State private var isPinned: Bool = false

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

                Section("Display") {
                    Toggle("Pinned", isOn: $isPinned)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
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
                        savePartner()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                // Set a default color for new partners
                avatarColor = Partner.randomColorName()
            }
        }
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
        newPartner.isPinned = isPinned
        modelContext.insert(newPartner)

        dismiss()
    }
}

#Preview("Add Partner") {
    PartnerFormView()
        .modelContainer(for: Partner.self, inMemory: true)
}
