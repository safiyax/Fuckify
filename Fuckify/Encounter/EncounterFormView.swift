//
//  EncounterFormView.swift
//  Fuckify
//
//  Encounter form using SQLite services
//

import SwiftUI
import SQLiteData
import Dependencies

struct EncounterFormView: View {
    @Dependency(\.encounterService) var encounterService
    @Dependency(\.partnerService) var partnerService
    @Environment(\.dismiss) private var dismiss

    @FetchAll(SQLPartner.order(by: \.name))
    private var allPartners: [SQLPartner]

    var encounter: SQLEncounter?
    var preselectedPartners: [SQLPartner] = []

    @State private var date: Date = Date()
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30
    @State private var selectedPartnerIDs: Set<UUID> = []
    @State private var selectedActivities: Set<SQLActivityType> = []
    @State private var selectedProtection: Set<SQLProtectionMethod> = []
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var rating: Int = 0
    @State private var reachedOrgasm: Bool = false
    @State private var settings = UserSettings.shared
    @State private var errorMessage: String?

    var isEditing: Bool {
        encounter != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date and Time
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("Hours", selection: $durationHours) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.menu)

                        Picker("Minutes", selection: $durationMinutes) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Partners
                Section("Partners") {
                    if allPartners.isEmpty {
                        Text("No partners available")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(allPartners) { partner in
                            Button(action: { togglePartner(partner.id) }) {
                                HStack {
                                    Text(partner.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedPartnerIDs.contains(partner.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // Activities
                Section("Activities") {
                    ForEach(SQLActivityType.allCases.filter { settings.isActivityEnabled($0) }, id: \.self) { activity in
                        Button(action: { toggleActivity(activity) }) {
                            HStack {
                                Image(systemName: activity.icon)
                                    .foregroundColor(.purple)
                                Text(activity.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedActivities.contains(activity) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                // Protection
                Section("Protection") {
                    ForEach(SQLProtectionMethod.allCases.filter { settings.isProtectionMethodEnabled($0) }, id: \.self) { protection in
                        Button(action: { toggleProtection(protection) }) {
                            HStack {
                                Image(systemName: protection.icon)
                                    .foregroundColor(.green)
                                Text(protection.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedProtection.contains(protection) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }

                // Experience
                Section("Experience") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating")
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: { rating = star }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(star <= rating ? .yellow : .gray)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Reached Orgasm", isOn: $reachedOrgasm)
                }

                // Location
                Section("Location") {
                    TextField("Location (optional)", text: $location)
                }

                // Notes
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
            .navigationTitle(isEditing ? "Edit Encounter" : "Add Encounter")
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
                            await saveEncounter()
                        }
                    }
                    .disabled(selectedPartnerIDs.isEmpty)
                }
            }
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        // Load encounter data if editing
        if let encounter = encounter {
            await loadEncounter(encounter)
        } else if !preselectedPartners.isEmpty {
            // Preselect partners
            selectedPartnerIDs = Set(preselectedPartners.map(\.id))
        }
    }

    private func togglePartner(_ partnerID: UUID) {
        if selectedPartnerIDs.contains(partnerID) {
            selectedPartnerIDs.remove(partnerID)
        } else {
            selectedPartnerIDs.insert(partnerID)
        }
    }

    private func toggleActivity(_ activity: SQLActivityType) {
        if selectedActivities.contains(activity) {
            selectedActivities.remove(activity)
        } else {
            selectedActivities.insert(activity)
        }
    }

    private func toggleProtection(_ protection: SQLProtectionMethod) {
        if selectedProtection.contains(protection) {
            selectedProtection.remove(protection)
        } else {
            selectedProtection.insert(protection)
        }
    }

    private func loadEncounter(_ encounter: SQLEncounter) async {
        date = encounter.date ?? Date()
        let totalMinutes = Int(encounter.duration / 60)
        durationHours = totalMinutes / 60
        durationMinutes = totalMinutes % 60
        location = encounter.location
        notes = encounter.notes
        rating = encounter.rating
        reachedOrgasm = encounter.reachedOrgasm
        
        // Load relationships
        do {
            let partners = try encounterService.fetchPartners(for: encounter.id)
            selectedPartnerIDs = Set(partners.map(\.id))
            
            let activities = try encounterService.fetchActivities(for: encounter.id)
            selectedActivities = Set(activities)
            
            let protectionMethods = try encounterService.fetchProtectionMethods(for: encounter.id)
            selectedProtection = Set(protectionMethods)
        } catch {
            errorMessage = "Failed to load encounter data"
        }
    }

    @MainActor
    private func saveEncounter() async {
        errorMessage = nil
        
        let duration = TimeInterval(durationHours * 3600 + durationMinutes * 60)
        let partnerIDs = Array(selectedPartnerIDs)

        do {
            if let encounter = encounter {
                // Edit existing encounter
                var updated = encounter
                updated.date = date
                updated.duration = duration
                updated.location = location
                updated.notes = notes
                updated.rating = rating
                updated.reachedOrgasm = reachedOrgasm
                
                let activities = Array(selectedActivities)
                let protection = Array(selectedProtection)
                
                try encounterService.update(
                    updated,
                    partnerIDs: partnerIDs,
                    activities: activities,
                    protectionMethods: protection
                )
                
                // Update partner last encounter dates
                for partnerID in partnerIDs {
                    try? partnerService.updateLastEncounterDate(partnerID, date: date)
                }
            } else {
                // Create new encounter
                let draft = SQLEncounter.Draft(
                    id: UUID(),
                    date: date,
                    duration: duration,
                    location: location,
                    notes: notes,
                    rating: rating,
                    reachedOrgasm: reachedOrgasm,
                    dateAdded: Date()
                )
                
                let activities = Array(selectedActivities)
                let protection = Array(selectedProtection)
                
                _ = try encounterService.create(
                    draft,
                    partnerIDs: partnerIDs,
                    activities: activities,
                    protectionMethods: protection
                )
                
                // Update partner last encounter dates
                for partnerID in partnerIDs {
                    try? partnerService.updateLastEncounterDate(partnerID, date: date)
                }
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save encounter. Please try again."
        }
    }
}

#Preview("Add Encounter") {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }

    return EncounterFormView()
}
