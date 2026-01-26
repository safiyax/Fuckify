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

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    var body: some View {
        List {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(isEditing ? Color.fromPartnerColorName(editAvatarColor) : partner.color)
                                .frame(width: 100, height: 100)

                            Text(isEditing ? editName.initials : partner.initials)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }

                        if !isEditing {
                            Text(partner.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            Text(partner.relationshipType.displayName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // Basic Information
            if isEditing {
                Section("Basic Information") {
                    TextField("Name", text: $editName)
                        .textContentType(.name)

                    TextField("Phone Number", text: $editPhoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }

                Section("Avatar Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 12) {
                        ForEach(PartnerColors.allColorNames, id: \.self) { colorName in
                            Button(action: { editAvatarColor = colorName }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.fromPartnerColorName(colorName))
                                        .frame(width: 50, height: 50)

                                    if editAvatarColor == colorName {
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
            } else {
                // Contact Information
                Section("Contact") {
                    if !partner.phoneNumber.isEmpty {
                        HStack {
                            Text("Phone")
                            Spacer()
                            Text(partner.phoneNumber)
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
                    if let dateMet = partner.dateMet {
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
                        Text(partner.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }

                    if let lastEncounter = partner.lastEncounterDate {
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
                } else {
                    HStack {
                        Text("PrEP Status")
                        Spacer()
                        if partner.isOnPrep {
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
                }
            }

            // Notes
            Section("Notes") {
                if isEditing {
                    TextEditor(text: $editNotes)
                        .frame(minHeight: 100)
                } else if !partner.notes.isEmpty {
                    Text(partner.notes)
                        .foregroundColor(.secondary)
                } else {
                    Text("No notes")
                        .foregroundColor(.secondary)
                }
            }

            // Encounters (only shown when not editing)
            if !isEditing {
                Section {
//                    // TODO: Update this section to use SQLEncounter
//                    HStack {
//                        Image(systemName: "heart.slash")
//                            .foregroundColor(.secondary)
//                        Text("Encounters list temporarily disabled during migration")
//                            .foregroundColor(.secondary)
//                            .font(.caption)
//                    }
                    if !sortedEncounters.isEmpty {
                        ForEach(sortedEncounters) { encounter in
                            NavigationLink {
                                EncounterDetailView(encounter: encounter)
                            } label: {
                                EncounterRowView(encounter: encounter)
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "heart.slash")
                                .foregroundStyle(.secondary)
                            Text("No encounters yet")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    HStack {
                        Text("Encounters")
                        if !sortedEncounters.isEmpty {
                            Text("(\(sortedEncounters.count))")
                                .foregroundColor(.secondary)
                        }
                    }
                }
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
                }
            }
        }
        .sheet(isPresented: $showingAddEncounter) {
            EncounterFormView(preselectedPartners: [partner])
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

    // MARK: - Computed Properties

    private var sortedEncounters: [SQLEncounter] {
        encounters.sorted(by: { 
            guard let date1 = $0.date, let date2 = $1.date else { return false }
            return date1 > date2 
        })
    }

    // MARK: - Functions

    private func loadEditableFields() {
        editName = partner.name
        editNotes = partner.notes
        editPhoneNumber = partner.phoneNumber
        editIsOnPrep = partner.isOnPrep
        editRelationshipType = partner.relationshipType
        editDateMet = partner.dateMet
        editShowDateMetPicker = partner.dateMet != nil
        editAvatarColor = partner.avatarColor
        editIsPinned = partner.isPinned
    }

    private func saveChanges() async {
        var updatedPartner = partner
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
    
    private func deleteEncounters(offsets: IndexSet) async {
        // Capture service before detached task to avoid actor isolation issues
        let service = encounterService
        
        for index in offsets {
            let encounter = sortedEncounters[index]
            do {
                // Perform database I/O off main thread
                try await Task.detached {
                    try await service.delete(encounter.id)
                }.value
                encounters.removeAll { $0.id == encounter.id }
            } catch {
                print("Failed to delete encounter: \(error)")
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
