//
//  EncounterDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SQLiteData
import Dependencies

struct EncounterDetailView: View {
    let encounter: SQLEncounter
    @State private var showingEditSheet = false
    @State private var partners: [SQLPartner] = []
    @State private var activities: [SQLActivityType] = []
    @State private var protectionMethods: [SQLProtectionMethod] = []
    @State private var isLoading = true
    @State private var currentEncounter: SQLEncounter
    
    @Dependency(\.encounterService) private var encounterService
    
    init(encounter: SQLEncounter) {
        self.encounter = encounter
        _currentEncounter = State(initialValue: encounter)
    }

    var body: some View {
        List {
            if isLoading {
                Section {
                    ProgressView("Loading...")
                }
            } else {
                // Date and Duration Section
                Section("When") {
                    if let date = currentEncounter.date {
                        HStack {
                            Text("Date")
                            Spacer()
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }

                    if !currentEncounter.duration.isZero {
                        HStack {
                            Text("Duration")
                            Spacer()
                            Text(currentEncounter.formattedDuration)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Partners Section
                Section("Partners") {
                    if !partners.isEmpty {
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
                                    .accessibilityHidden(true)

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
                if !activities.isEmpty {
                    Section("Activities") {
                        ForEach(activities, id: \.self) { activity in
                            HStack {
                                Image(systemName: activity.icon)
                                    .foregroundColor(.purple)
                                    .accessibilityHidden(true)
                                Text(activity.displayName)
                            }
                        }
                    }
                }

                // Protection Section
                if !protectionMethods.isEmpty {
                    Section("Protection") {
                        ForEach(protectionMethods, id: \.self) { protection in
                            HStack {
                                Image(systemName: protection.icon)
                                    .foregroundColor(.green)
                                    .accessibilityHidden(true)
                                Text(protection.displayName)
                            }
                        }
                    }
                }

                // Experience Section
                Section("Experience") {
                    if currentEncounter.rating > 0 {
                        HStack {
                            Text("Rating")
                            Spacer()
                            HStack(spacing: 4) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= currentEncounter.rating ? "star.fill" : "star")
                                        .foregroundColor(star <= currentEncounter.rating ? .yellow : .gray)
                                        .font(.caption)
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Rating")
                            .accessibilityValue("\(currentEncounter.rating) out of 5 stars")
                        }
                    }

                    HStack {
                        Text("Orgasm")
                        Spacer()
                        if currentEncounter.reachedOrgasm {
                            Label("Yes", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Text("No")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Location Section
                if !currentEncounter.location.isEmpty {
                    Section("Location") {
                        Text(currentEncounter.location)
                            .foregroundColor(.secondary)
                    }
                }

                // Notes Section
                if !currentEncounter.notes.isEmpty {
                    Section("Notes") {
                        Text(currentEncounter.notes)
                            .foregroundColor(.secondary)
                    }
                }

                // Metadata Section
                Section("Details") {
                    HStack {
                        Text("Added")
                        Spacer()
                        Text(currentEncounter.dateAdded.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(.secondary)
                    }
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
        .onChange(of: showingEditSheet) { _, isShowing in
            if !isShowing {
                // Sheet was dismissed, refresh encounter data
                Task {
                    await refreshEncounter()
                }
            }
        }
        .task {
            await loadEncounterData()
        }
    }
    
    @MainActor
    private func loadEncounterData() async {
        isLoading = true
        
        // Capture service before detached task to avoid actor isolation issues
        let service = encounterService
        let encounterId = encounter.id
        
        // Load all relationships - perform database I/O off main thread
        do {
            partners = try service.fetchPartners(for: encounterId)
            activities = try service.fetchActivities(for: encounterId)
            protectionMethods = try service.fetchProtectionMethods(for: encounterId)
        } catch {
            // Silent error handling - keep empty arrays
        }
        
        isLoading = false
    }
    
    @MainActor
    private func refreshEncounter() async {
        // Fetch the updated encounter from database
        let service = encounterService
        let encounterId = encounter.id
        
        do {
            if let updatedEncounter = try service.fetchByID(encounterId) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentEncounter = updatedEncounter
                }
            }
            // Also reload related data
            partners = try service.fetchPartners(for: encounterId)
            activities = try service.fetchActivities(for: encounterId)
            protectionMethods = try service.fetchProtectionMethods(for: encounterId)
        } catch {
            // Silent error handling
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    let encounter = SQLEncounter(
        id: UUID(),
        date: Date(),
        duration: 3600,
        location: "Home",
        notes: "Great time!",
        rating: 5,
        reachedOrgasm: true,
        dateAdded: Date()
    )

    NavigationStack {
        EncounterDetailView(encounter: encounter)
    }
}
