//
//  PartnerDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @Bindable var partner: Partner
    @State private var showingAddEncounter = false

    // Editable fields
    @State private var editName: String = ""
    @State private var editNotes: String = ""
    @State private var editPhoneNumber: String = ""
    @State private var editIsOnPrep: Bool = false
    @State private var editRelationshipType: RelationshipType = .casual
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
                                .fill(isEditing ? colorFromName(editAvatarColor) : partner.color)
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
                        ForEach(["blue", "purple", "pink", "red", "orange", "yellow", "green", "teal", "indigo"], id: \.self) { colorName in
                            Button(action: { editAvatarColor = colorName }) {
                                ZStack {
                                    Circle()
                                        .fill(colorFromName(colorName))
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
                        ForEach([RelationshipType.casual, .regular, .committed, .oneTime, .other], id: \.self) { type in
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
                    if !sortedEncounters.isEmpty {
                        ForEach(sortedEncounters) { encounter in
                            NavigationLink {
                                EncounterDetailView(encounter: encounter)
                            } label: {
                                EncounterRowView(encounter: encounter)
                            }
                        }
                        .onDelete(perform: deleteEncounters)
                    } else {
                        HStack {
                            Image(systemName: "heart.slash")
                                .foregroundColor(.secondary)
                            Text("No encounters yet")
                                .foregroundColor(.secondary)
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
            EncounterFormView(preselectedPartner: partner)
        }
        .onAppear {
            loadEditableFields()
        }
        .onChange(of: editMode?.wrappedValue) { oldValue, newValue in
            if oldValue?.isEditing == true && newValue?.isEditing == false {
                // Save changes when exiting edit mode
                saveChanges()
            } else if oldValue?.isEditing == false && newValue?.isEditing == true {
                // Reload fields when entering edit mode
                loadEditableFields()
            }
        }
    }

    // MARK: - Computed Properties

    private var sortedEncounters: [Encounter] {
        guard let encounters = partner.encounters else { return [] }
        return encounters.sorted(by: { $0.date > $1.date })
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

    private func saveChanges() {
        partner.name = editName
        partner.notes = editNotes
        partner.phoneNumber = editPhoneNumber
        partner.isOnPrep = editIsOnPrep
        partner.relationshipType = editRelationshipType
        partner.dateMet = editShowDateMetPicker ? editDateMet : nil
        partner.avatarColor = editAvatarColor
        partner.isPinned = editIsPinned
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

    private func deleteEncounters(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sortedEncounters[index])
            }
        }
    }
}

// Extension to get initials from String
extension String {
    var initials: String {
        let words = self.split(separator: " ")
        if words.isEmpty { return "" }
        if words.count == 1 {
            return String(words[0].prefix(1)).uppercased()
        }
        return (String(words.first?.first ?? " ") + String(words.last?.first ?? " ")).uppercased()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Partner.self, Encounter.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let partner = Partner(
        name: "John Doe",
        notes: "Met at the gym, really nice person",
        phoneNumber: "555-0123",
        isOnPrep: true,
        relationshipType: .regular,
        dateMet: Date().addingTimeInterval(-86400 * 30)
    )
    partner.lastEncounterDate = Date().addingTimeInterval(-86400 * 7)
    container.mainContext.insert(partner)

    // Add some sample encounters
    let encounter1 = Encounter(
        date: Date().addingTimeInterval(-86400 * 7),
        duration: 3600,
        activities: [.oral, .vaginal],
        protectionMethods: [.condom],
        partners: [partner]
    )

    let encounter2 = Encounter(
        date: Date().addingTimeInterval(-86400 * 14),
        duration: 2400,
        activities: [.kissing, .manual],
        protectionMethods: [.prep],
        partners: [partner]
    )

    container.mainContext.insert(encounter1)
    container.mainContext.insert(encounter2)

    return NavigationStack {
        PartnerDetailView(partner: partner)
    }
    .modelContainer(container)
}
