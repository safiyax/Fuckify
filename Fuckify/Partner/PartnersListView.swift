//
//  PartnersListView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Partner.name) private var partners: [Partner]
    @State private var showingAddPartner = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(partners) { partner in
                    NavigationLink {
                        PartnerDetailView(partner: partner)
                    } label: {
                        PartnerRowView(partner: partner)
                    }
                }
                .onDelete(perform: deletePartners)
            }
            .navigationTitle("Partners")
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
                    Button(action: { showingAddPartner = true }) {
                        Label("Add Partner", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPartner) {
                PartnerFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .overlay {
                if partners.isEmpty {
                    ContentUnavailableView(
                        "No Partners",
                        systemImage: "person.2.slash",
                        description: Text("Add a partner to get started")
                    )
                }
            }
        }
    }

    private func deletePartners(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(partners[index])
            }
        }
    }
}

// MARK: - Partner Row View

struct PartnerRowView: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 12) {
            // Initials Avatar
            ZStack {
                Circle()
                    .fill(partner.color)
                    .frame(width: 50, height: 50)

                Text(partner.initials)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(partner.name)
                    .font(.headline)

                HStack {
                    Text(partner.relationshipType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if partner.isOnPrep {
                        Text("• PrEP")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                if let lastEncounter = partner.lastEncounterDate {
                    Text("Last: \(lastEncounter.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PartnersListView()
        .modelContainer(for: Partner.self, inMemory: true)
}
