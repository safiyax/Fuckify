//
//  PartnerDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SQLiteData
import Dependencies

struct PartnerDetailView: View {
    let partner: SQLPartner
    @Environment(\.editMode) private var editMode
    @State private var showingAddEncounter = false
    @State private var encounters: [SQLEncounter] = []
    @State private var isLoadingEncounters = true
    @State private var currentPartner: SQLPartner
    
    @Dependency(\.partnerService) private var partnerService
    @Dependency(\.encounterService) private var encounterService

    // Editable fields
    @State private var editName: String = ""
    @State private var editNotes: String = ""
    @State private var editPhoneNumber: String = ""
    @State private var editIsOnPrep: Bool = false
    @State private var editRelationshipType: SQLRelationshipType = .casual
    @State private var editDateMet: Date?
    @State private var editShowDateMetPicker: Bool = false
    @State private var editAvatarColor: String = ""
    @State private var editIsPinned: Bool = false
    
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
                } else {
                    if let dateMet = currentPartner.dateMet {
                        HStack {
                            Text("Date Met")
                            Spacer()
                            Text(dateMet.formatted(date: .abbreviated, time: .omitted))
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

            // Health Information
            Section("Health") {
                if isEditing {
                    Toggle("On PrEP", isOn: $editIsOnPrep)
                        .accessibilityHint("Indicates whether this partner is on pre-exposure prophylaxis")
                } else {
                    HStack {
                        Text("PrEP Status")
                        Spacer()
                        if currentPartner.isOnPrep {
                            Label("On PrEP", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        } else {
                            Text("Not on PrEP")
                                .foregroundColor(.secondary)
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
        }
        .onChange(of: editMode?.wrappedValue) { oldValue, newValue in
            if oldValue?.isEditing == true && newValue?.isEditing == false {
                // Save changes when exiting edit mode
                Task {
                    await saveChanges()
                }
            } else if oldValue?.isEditing == false && newValue?.isEditing == true {
                // Reload fields when entering edit mode
                loadEditableFields()
            }
        }
    }

    // MARK: - Functions

    private func loadEditableFields() {
        editName = currentPartner.name
        editNotes = currentPartner.notes
        editPhoneNumber = currentPartner.phoneNumber
        editIsOnPrep = currentPartner.isOnPrep
        editRelationshipType = currentPartner.relationshipType
        editDateMet = currentPartner.dateMet
        editShowDateMetPicker = currentPartner.dateMet != nil
        editAvatarColor = currentPartner.avatarColor
        editIsPinned = currentPartner.isPinned
    }

    private func saveChanges() async {
        var updatedPartner = currentPartner
        updatedPartner.name = editName
        updatedPartner.notes = editNotes
        updatedPartner.phoneNumber = editPhoneNumber
        updatedPartner.isOnPrep = editIsOnPrep
        updatedPartner.relationshipType = editRelationshipType
        updatedPartner.dateMet = editShowDateMetPicker ? editDateMet : nil
        updatedPartner.avatarColor = editAvatarColor
        updatedPartner.isPinned = editIsPinned
        
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
            print("Failed to update partner: \(error)")
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
            print("Failed to load encounters: \(error)")
        }
        
        isLoadingEncounters = false
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
        isOnPrep: true,
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
