//
//  PartnerFormView.swift
//  Fuckify
//
//  Partner form using SQLite services
//

import SwiftUI
import SQLiteData
import Dependencies

struct PartnerFormView: View {
    @Dependency(\.partnerService) var partnerService
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var phoneNumber: String = ""
    @State private var isOnPrep: Bool = false
    @State private var relationshipType: SQLRelationshipType = .casual
    @State private var dateMet: Date?
    @State private var showDateMetPicker: Bool = false
    @State private var avatarColor: String = ""
    @State private var isPinned: Bool = false
    @State private var errorMessage: String?

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
            .onAppear {
                // Set a default color for new partners
                avatarColor = PartnerColors.randomColorName()
            }
        }
    }



    private func savePartner() async {
        errorMessage = nil
        
        // Create partner draft
        let draft = SQLPartner.Draft(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            notes: notes,
            phoneNumber: phoneNumber,
            isOnPrep: isOnPrep,
            relationshipType: relationshipType,
            dateMet: showDateMetPicker ? dateMet : nil,
            avatarColor: avatarColor.isEmpty ? PartnerColors.randomColorName() : avatarColor,
            dateAdded: Date(),
            lastEncounterDate: nil,
            isPinned: isPinned
        )
        
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = partnerService
            
            // Perform database I/O off main thread
            try await Task.detached {
                try service.create(draft)
            }.value
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
