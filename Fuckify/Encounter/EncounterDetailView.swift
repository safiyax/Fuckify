//
//  EncounterDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct EncounterDetailView: View {
    @Bindable var encounter: Encounter
    @State private var showingEditSheet = false

    var body: some View {
        List {
            // Date and Duration Section
            Section("When") {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }

                if !encounter.duration.isZero {
                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(encounter.formattedDuration)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Partners Section
            Section("Partners") {
                if let partners = encounter.partners, !partners.isEmpty {
                    ForEach(partners) { partner in
                        NavigationLink {
                            PartnerDetailView(partner: partner)
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(partner.color)
                                        .frame(width: 35, height: 35)

                                    Text(partner.initials)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }

                                Text(partner.name)
                            }
                        }
                    }
                } else {
                    Text("No partners recorded")
                        .foregroundColor(.secondary)
                }
            }

            // Activities Section
            if !encounter.activities.isEmpty {
                Section("Activities") {
                    ForEach(encounter.activities, id: \.self) { activity in
                        HStack {
                            Image(systemName: activity.icon)
                                .foregroundColor(.purple)
                            Text(activity.displayName)
                        }
                    }
                }
            }

            // Protection Section
            if !encounter.protectionMethods.isEmpty {
                Section("Protection") {
                    ForEach(encounter.protectionMethods, id: \.self) { protection in
                        HStack {
                            Image(systemName: protection.icon)
                                .foregroundColor(.green)
                            Text(protection.displayName)
                        }
                    }
                }
            }

            // Experience Section
            Section("Experience") {
                if encounter.rating > 0 {
                    HStack {
                        Text("Rating")
                        Spacer()
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: star <= encounter.rating ? "star.fill" : "star")
                                    .foregroundColor(star <= encounter.rating ? .yellow : .gray)
                                    .font(.caption)
                            }
                        }
                    }
                }

                HStack {
                    Text("Orgasm")
                    Spacer()
                    if encounter.reachedOrgasm {
                        Label("Yes", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Text("No")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Location Section
            if !encounter.location.isEmpty {
                Section("Location") {
                    Text(encounter.location)
                        .foregroundColor(.secondary)
                }
            }

            // Notes Section
            if !encounter.notes.isEmpty {
                Section("Notes") {
                    Text(encounter.notes)
                        .foregroundColor(.secondary)
                }
            }

            // Metadata Section
            Section("Details") {
                HStack {
                    Text("Added")
                    Spacer()
                    Text(encounter.dateAdded.formatted(date: .abbreviated, time: .shortened))
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Encounter")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EncounterFormView(encounter: encounter)
        }
    }
}

#Preview {
    let container = try! ModelContainer(for: Partner.self, Encounter.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))

    let partner1 = Partner(name: "John Doe")
    let partner2 = Partner(name: "Jane Smith")
    container.mainContext.insert(partner1)
    container.mainContext.insert(partner2)

    let encounter = Encounter(
        date: Date(),
        duration: 3600,
        activities: [.oral, .vaginal, .kissing],
        protectionMethods: [.condom, .prep],
        location: "Home",
        notes: "Great time!",
        partners: [partner1, partner2]
    )
    container.mainContext.insert(encounter)

    return NavigationStack {
        EncounterDetailView(encounter: encounter)
    }
    .modelContainer(container)
}
