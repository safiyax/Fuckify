//
//  EncounterFormView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct EncounterFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Partner.name) private var allPartners: [Partner]

    var encounter: Encounter?

    @State private var date: Date = Date()
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30
    @State private var selectedPartners: Set<Partner> = []
    @State private var selectedActivities: Set<ActivityType> = []
    @State private var selectedProtection: Set<ProtectionMethod> = []
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var rating: Int = 0
    @State private var reachedOrgasm: Bool = false
    @State private var settings = UserSettings.shared

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
                            Button(action: { togglePartner(partner) }) {
                                HStack {
                                    Text(partner.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedPartners.contains(partner) {
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
                    ForEach(ActivityType.allCases.filter { settings.isActivityEnabled($0) }, id: \.self) { activity in
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
                    ForEach(ProtectionMethod.allCases.filter { settings.isProtectionMethodEnabled($0) }, id: \.self) { protection in
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
                        saveEncounter()
                    }
                }
            }
            .onAppear {
                if let encounter = encounter {
                    loadEncounter(encounter)
                }
            }
        }
    }

    private func togglePartner(_ partner: Partner) {
        if selectedPartners.contains(partner) {
            selectedPartners.remove(partner)
        } else {
            selectedPartners.insert(partner)
        }
    }

    private func toggleActivity(_ activity: ActivityType) {
        if selectedActivities.contains(activity) {
            selectedActivities.remove(activity)
        } else {
            selectedActivities.insert(activity)
        }
    }

    private func toggleProtection(_ protection: ProtectionMethod) {
        if selectedProtection.contains(protection) {
            selectedProtection.remove(protection)
        } else {
            selectedProtection.insert(protection)
        }
    }

    private func loadEncounter(_ encounter: Encounter) {
        date = encounter.date
        let totalMinutes = Int(encounter.duration / 60)
        durationHours = totalMinutes / 60
        durationMinutes = totalMinutes % 60
        selectedPartners = Set(encounter.partners ?? [])
        selectedActivities = Set(encounter.activities)
        selectedProtection = Set(encounter.protectionMethods)
        location = encounter.location
        notes = encounter.notes
        rating = encounter.rating
        reachedOrgasm = encounter.reachedOrgasm
    }

    private func saveEncounter() {
        let duration = TimeInterval(durationHours * 3600 + durationMinutes * 60)
        let partnersList = Array(selectedPartners)

        if let encounter = encounter {
            // Edit existing encounter
            encounter.date = date
            encounter.duration = duration
            encounter.partners = partnersList
            encounter.activities = Array(selectedActivities)
            encounter.protectionMethods = Array(selectedProtection)
            encounter.location = location
            encounter.notes = notes
            encounter.rating = rating
            encounter.reachedOrgasm = reachedOrgasm
        } else {
            // Create new encounter
            let newEncounter = Encounter(
                date: date,
                duration: duration,
                activities: Array(selectedActivities),
                protectionMethods: Array(selectedProtection),
                location: location,
                notes: notes,
                rating: rating,
                reachedOrgasm: reachedOrgasm,
                partners: partnersList
            )
            modelContext.insert(newEncounter)
        }

        // Update lastEncounterDate for all partners
        for partner in selectedPartners {
            if partner.lastEncounterDate == nil || partner.lastEncounterDate! < date {
                partner.lastEncounterDate = date
            }
        }

        dismiss()
    }
}

#Preview("Add Encounter") {
    let container = try! ModelContainer(for: Partner.self, Encounter.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    let partner1 = Partner(name: "John Doe")
    let partner2 = Partner(name: "Jane Smith")
    container.mainContext.insert(partner1)
    container.mainContext.insert(partner2)

    return EncounterFormView()
        .modelContainer(container)
}
