//
//  EncountersListView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct EncountersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Encounter.date, order: .reverse) private var encounters: [Encounter]
    @State private var showingAddEncounter = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(encounters) { encounter in
                    NavigationLink {
                        EncounterDetailView(encounter: encounter)
                    } label: {
                        EncounterRowView(encounter: encounter)
                    }
                }
                .onDelete(perform: deleteEncounters)
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { showingAddEncounter = true }) {
                        Label("Add Encounter", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddEncounter) {
                EncounterFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay {
                if encounters.isEmpty {
                    ContentUnavailableView(
                        "No Encounters",
                        systemImage: "heart.slash",
                        description: Text("Add an encounter to get started")
                    )
                }
            }
        }
    }

    private func deleteEncounters(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(encounters[index])
            }
        }
    }
}

// MARK: - Encounter Row View

struct EncounterRowView: View {
    let encounter: Encounter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and Partners
            HStack {
                Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)

                Spacer()

                if !encounter.duration.isZero {
                    Text(encounter.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Partners
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.caption)

                Text(encounter.partnerNames)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Activities and Protection
            HStack(spacing: 12) {
                if !encounter.activities.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(encounter.activities.prefix(3), id: \.self) { activity in
                            Image(systemName: activity.icon)
                                .foregroundColor(.purple)
                                .font(.caption)
                        }
                        if encounter.activities.count > 3 {
                            Text("+\(encounter.activities.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !encounter.protectionMethods.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(encounter.protectionMethods.prefix(2), id: \.self) { protection in
                            Image(systemName: protection.icon)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let container = try! ModelContainer(for: Encounter.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    let partner1 = Partner(name: "John Doe")
    let partner2 = Partner(name: "Jane Smith")
    container.mainContext.insert(partner1)
    container.mainContext.insert(partner2)

    let encounter1 = Encounter(
        date: Date(),
        duration: 3600,
        activities: [.oral, .vaginal],
        protectionMethods: [.condom],
        partners: [partner1]
    )

    let encounter2 = Encounter(
        date: Date().addingTimeInterval(-86400 * 2),
        duration: 1800,
        activities: [.kissing, .manual, .oral],
        protectionMethods: [.prep],
        partners: [partner1, partner2]
    )

    container.mainContext.insert(encounter1)
    container.mainContext.insert(encounter2)

    return EncountersListView()
        .modelContainer(container)
}
