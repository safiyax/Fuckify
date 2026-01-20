//
//  EncountersListView.swift
//  Fuckify
//
//  Encounters list using SQLiteData
//

import SwiftUI
import SQLiteData
import Dependencies

struct EncountersListView: View {
    @FetchAll(SQLEncounter.order { $0.date.desc() })
    private var encounters: [SQLEncounter]
    
    @Dependency(\.encounterService) var encounterService
    
    @State private var showingAddEncounter = false
    @State private var showingSettings = false
    @State private var showProfile = false
    @State private var profile = UserProfile.shared
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(encounters) { encounter in
                    // TODO: Update EncounterDetailView to use SQLEncounter
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
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { showingAddEncounter = true }) {
                        Label("Add Encounter", systemImage: "plus")
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: { showProfile = true }) {
                        ZStack {
                            Text(profile.initials)
                        }
                    }
                    .buttonStyle(.compatibleGlassProminent)
                }
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showingAddEncounter) {
                EncounterFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showProfile, content: {
                ProfileView()
            })
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
                do {
                    try encounterService.delete(encounters[index].id)
                } catch {
                    // TODO: Show error to user
                    print("Failed to delete encounter: \(error)")
                }
            }
        }
    }
}

// MARK: - Encounter Row View

struct EncounterRowView: View {
    let encounter: SQLEncounter
    
    @Dependency(\.encounterService) var encounterService
    @State private var partners: [SQLPartner] = []
    @State private var activities: [SQLActivityType] = []
    @State private var protectionMethods: [SQLProtectionMethod] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and Duration
            HStack {
                if let date = encounter.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                } else {
                    Text("No date")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if encounter.duration > 0 {
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

                Text(partnerNames)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Activities and Protection
            HStack(spacing: 12) {
                if !activities.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(activities.prefix(3), id: \.self) { activity in
                            Image(systemName: activity.icon)
                                .foregroundColor(.purple)
                                .font(.caption)
                        }
                        if activities.count > 3 {
                            Text("+\(activities.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !protectionMethods.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(protectionMethods.prefix(2), id: \.self) { protection in
                            Image(systemName: protection.icon)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            await loadRelationships()
        }
    }
    
    private var partnerNames: String {
        guard !partners.isEmpty else { return "No partners" }
        return partners.map(\.name).joined(separator: ", ")
    }
    
    private func loadRelationships() async {
        do {
            partners = try encounterService.fetchPartners(for: encounter.id)
            activities = try encounterService.fetchActivities(for: encounter.id)
            protectionMethods = try encounterService.fetchProtectionMethods(for: encounter.id)
        } catch {
            // Silent fail - relationships will be empty
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return EncountersListView()
}
