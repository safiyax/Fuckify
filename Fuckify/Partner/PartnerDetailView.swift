//
//  PartnerDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnerDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var partner: Partner
    @State private var showingEditSheet = false
    @State private var showingAddEncounter = false

    var body: some View {
        List {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(partner.color)
                                .frame(width: 100, height: 100)

                            Text(partner.initials)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text(partner.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(partner.relationshipType.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

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

            // Relationship Details
            Section("Relationship") {
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

            // Health Information
            Section("Health") {
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

            // Notes
            if !partner.notes.isEmpty {
                Section("Notes") {
                    Text(partner.notes)
                        .foregroundColor(.secondary)
                }
            }

            // Encounters
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
        .navigationTitle("Partner Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddEncounter = true }) {
                    Label("Add Encounter", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            PartnerFormView(partner: partner)
        }
        .sheet(isPresented: $showingAddEncounter) {
            EncounterFormView(preselectedPartner: partner)
        }
    }

    // MARK: - Computed Properties

    private var sortedEncounters: [Encounter] {
        guard let encounters = partner.encounters else { return [] }
        return encounters.sorted(by: { $0.date > $1.date })
    }

    // MARK: - Functions

    private func deleteEncounters(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sortedEncounters[index])
            }
        }
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
