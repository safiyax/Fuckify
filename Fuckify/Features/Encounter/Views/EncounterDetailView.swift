//
//  EncounterDetailView.swift
//  Fuckify
//
//

import SwiftUI
import SQLiteData
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "EncounterDetailView")

struct EncounterDetailView: View {
    let encounter: SQLEncounter
    @State private var showingEditSheet = false
    @State private var partners: [SQLPartner] = []
    @State private var activityEntities: [SQLActivityTypeEntity] = []       // NEW: Entity-based
    @State private var protectionEntities: [SQLProtectionMethodEntity] = [] // NEW: Entity-based
    @State private var partnerPositions: [UUID: SQLPositionType] = [:]
    @State private var partnerOrgasms: [UUID: Bool] = [:]
    @State private var myPosition: SQLPositionType? = nil
    @State private var isLoading = true
    @State private var currentEncounter: SQLEncounter
    @State private var selectedPartner: SQLPartner?
    
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

                if myPosition != nil || currentEncounter.reachedOrgasm {
                    Section("Me") {
                        if let myPos = myPosition {
                            Label(myPos.name, systemImage: myPos.icon)
                        }
                        if currentEncounter.reachedOrgasm {
                            Label("Orgasm", systemImage: "heart.fill")
                        }
                    }
                }

                // Partners Section
                Section("Partners") {
                    if !partners.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(partners) { partner in
                                VStack(alignment: .leading, spacing: 4) {
                                    Button {
                                        selectedPartner = partner
                                    } label: {
                                        EncounterDetailPartnerChip(partner: partner)
                                    }
                                    .buttonStyle(.plain)

                                    HStack(spacing: 8) {
                                        if let position = partnerPositions[partner.id] {
                                            Label(position.name, systemImage: position.icon)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if partnerOrgasms[partner.id] == true {
                                            Label("Orgasm", systemImage: "heart.fill")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.leading, 4)
                                }
                            }
                        }
                        .padding(4)
                    } else {
                        Text("No partners recorded")
                            .foregroundColor(.secondary)
                    }
                }

                // Activities Section
                if !activityEntities.isEmpty {
                    Section("Activities") {
                        ForEach(activityEntities) { activity in
                            HStack {
                                Image(systemName: activity.icon)
                                    .foregroundColor(.purple)
                                    .accessibilityHidden(true)
                                Text(activity.name)
                            }
                        }
                    }
                }

                // Protection Section
                if !protectionEntities.isEmpty {
                    Section("Protection") {
                        ForEach(protectionEntities) { protection in
                            HStack {
                                Image(systemName: protection.icon)
                                    .foregroundColor(.green)
                                    .accessibilityHidden(true)
                                Text(protection.name)
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
        .navigationDestination(item: $selectedPartner) { partner in
            PartnerDetailView(partner: partner)
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
            activityEntities = try service.fetchActivityEntities(for: encounterId)              // NEW
            protectionEntities = try service.fetchProtectionMethodEntities(for: encounterId)   // NEW
        } catch {
            logger.error("Failed to load encounter details for \(encounterId): \(error.localizedDescription)")
        }

        // Load partner positions
        do {
            let junctions = try service.fetchEncounterPartnerJunctions(for: encounterId)
            let allPositionIDs = Set(junctions.compactMap { $0.positionTypeId })
            // Always load orgasm status from all junctions
            for junction in junctions {
                partnerOrgasms[junction.partnerId] = junction.hadOrgasm
            }
            if !allPositionIDs.isEmpty {
                let posTypes = try PositionTypeService().fetchAll()
                let posDict = Dictionary(uniqueKeysWithValues: posTypes.map { ($0.id, $0) })
                for junction in junctions {
                    if let posId = junction.positionTypeId, let pos = posDict[posId] {
                        partnerPositions[junction.partnerId] = pos
                    }
                }
            }
            if let myPosId = currentEncounter.positionTypeId {
                myPosition = try PositionTypeService().fetchAll().first { $0.id == myPosId }
            }
        } catch {
            // Non-fatal — positions just won't show
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
            activityEntities = try service.fetchActivityEntities(for: encounterId)              // NEW
            protectionEntities = try service.fetchProtectionMethodEntities(for: encounterId)   // NEW

            // Reload positions
            let junctions = try service.fetchEncounterPartnerJunctions(for: encounterId)
            var newPartnerPositions: [UUID: SQLPositionType] = [:]
            var newPartnerOrgasms: [UUID: Bool] = [:]
            let allPositionIDs = Set(junctions.compactMap { $0.positionTypeId })
            if !allPositionIDs.isEmpty {
                let posTypes = try PositionTypeService().fetchAll()
                let posDict = Dictionary(uniqueKeysWithValues: posTypes.map { ($0.id, $0) })
                for junction in junctions {
                    if let posId = junction.positionTypeId, let pos = posDict[posId] {
                        newPartnerPositions[junction.partnerId] = pos
                    }
                    newPartnerOrgasms[junction.partnerId] = junction.hadOrgasm
                }
            } else {
                for junction in junctions {
                    newPartnerOrgasms[junction.partnerId] = junction.hadOrgasm
                }
            }
            partnerPositions = newPartnerPositions
            partnerOrgasms = newPartnerOrgasms
            if let myPosId = currentEncounter.positionTypeId {
                myPosition = try PositionTypeService().fetchAll().first { $0.id == myPosId }
            } else {
                myPosition = nil
            }
        } catch {
            logger.error("Failed to refresh encounter \(encounterId): \(error.localizedDescription)")
        }
    }
}

// MARK: - Encounter Detail Partner Chip

struct EncounterDetailPartnerChip: View {
    let partner: SQLPartner
    
    var partnerColor: Color {
        Color.fromPartnerColorName(partner.avatarColor)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(partner.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(partnerColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            partnerColor
                .opacity(0.15)
        )
        .cornerRadius(16)
    }
}

// MARK: - Chip Container for Detail View

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
