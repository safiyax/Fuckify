//
//  PartnerDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnerDetailView: View {
    @Bindable var partner: Partner
    @State private var showingEditSheet = false

    var body: some View {
        List {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(avatarColor(for: partner.name))
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
        }
        .navigationTitle("Partner Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            PartnerFormView(partner: partner)
        }
    }

    // Generate consistent color based on name
    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .pink, .red, .orange, .yellow, .green, .teal, .indigo]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

#Preview {
    let container = try! ModelContainer(for: Partner.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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

    return NavigationStack {
        PartnerDetailView(partner: partner)
    }
    .modelContainer(container)
}
