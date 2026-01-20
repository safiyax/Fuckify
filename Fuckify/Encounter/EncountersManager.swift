//
//  EncountersManager.swift
//  Fuckify
//
//  Manager for encounter operations using SQLite services
//

import Foundation
import Dependencies
import OSLog

private let logger = Logger(subsystem: "com.fuckify", category: "EncountersManager")

@Observable
class EncountersManager {
    @ObservationIgnored
    @Dependency(\.encounterService) private var encounterService
    
    @ObservationIgnored
    @Dependency(\.partnerService) private var partnerService

    var encounters: [SQLEncounter] = []
    var searchText: String = ""
    var errorMessage: String?
    var isLoading = false

    init() {
        fetchEncounters()
    }

    // MARK: - Data Operations

    func fetchEncounters() {
        isLoading = true
        errorMessage = nil
        
        do {
            encounters = try encounterService.fetchAll()
            logger.info("Fetched \(self.encounters.count) encounters")
        } catch {
            logger.error("Failed to fetch encounters: \(error.localizedDescription)")
            errorMessage = "Unable to load encounters. Please try again."
            encounters = []
        }
        
        isLoading = false
    }

    func addEncounter(
        _ encounterDraft: SQLEncounter.Draft,
        partnerIDs: [UUID],
        activities: [SQLActivityType],
        protectionMethods: [SQLProtectionMethod]
    ) {
        do {
            let encounterID = try encounterService.create(
                encounterDraft,
                partnerIDs: partnerIDs,
                activities: activities,
                protectionMethods: protectionMethods
            )
            logger.info("Created encounter: \(encounterID)")
            
            // Update last encounter date for all partners
            if let date = encounterDraft.date {
                for partnerID in partnerIDs {
                    try? partnerService.updateLastEncounterDate(partnerID, date: date)
                }
            }
            
            fetchEncounters()
        } catch {
            logger.error("Failed to create encounter: \(error.localizedDescription)")
            errorMessage = "Unable to create encounter. Please try again."
        }
    }

    func updateEncounter(
        _ encounter: SQLEncounter,
        partnerIDs: [UUID]? = nil,
        activities: [SQLActivityType]? = nil,
        protectionMethods: [SQLProtectionMethod]? = nil
    ) {
        do {
            try encounterService.update(
                encounter,
                partnerIDs: partnerIDs,
                activities: activities,
                protectionMethods: protectionMethods
            )
            logger.info("Updated encounter: \(encounter.id)")
            
            // Update last encounter date for partners if date changed
            if let date = encounter.date, let partnerIDs = partnerIDs {
                for partnerID in partnerIDs {
                    try? partnerService.updateLastEncounterDate(partnerID, date: date)
                }
            }
            
            fetchEncounters()
        } catch {
            logger.error("Failed to update encounter: \(error.localizedDescription)")
            errorMessage = "Unable to update encounter. Please try again."
        }
    }

    func deleteEncounter(_ encounter: SQLEncounter) {
        do {
            try encounterService.delete(encounter.id)
            logger.info("Deleted encounter: \(encounter.id)")
            fetchEncounters()
        } catch {
            logger.error("Failed to delete encounter: \(error.localizedDescription)")
            errorMessage = "Unable to delete encounter. Please try again."
        }
    }

    func deleteEncounters(at offsets: IndexSet, from filteredList: [SQLEncounter]) {
        for index in offsets {
            deleteEncounter(filteredList[index])
        }
    }

    // MARK: - Computed Properties

    var filteredEncounters: [SQLEncounter] {
        if searchText.isEmpty {
            return encounters
        }
        return encounters.filter { encounter in
            encounter.location.localizedCaseInsensitiveContains(searchText) ||
            encounter.notes.localizedCaseInsensitiveContains(searchText)
            // TODO: Filter by partner names once we have them loaded
        }
    }

    var encounterCount: Int {
        encounters.count
    }
    
    // MARK: - Helper Methods
    
    /// Get partners for a specific encounter
    func partners(for encounter: SQLEncounter) -> [SQLPartner] {
        do {
            return try encounterService.fetchPartners(for: encounter.id)
        } catch {
            logger.error("Failed to fetch partners for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activities for a specific encounter
    func activities(for encounter: SQLEncounter) -> [SQLActivityType] {
        do {
            return try encounterService.fetchActivities(for: encounter.id)
        } catch {
            logger.error("Failed to fetch activities for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get protection methods for a specific encounter
    func protectionMethods(for encounter: SQLEncounter) -> [SQLProtectionMethod] {
        do {
            return try encounterService.fetchProtectionMethods(for: encounter.id)
        } catch {
            logger.error("Failed to fetch protection methods for encounter: \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Dependency Key

extension EncounterService: DependencyKey {
    static var liveValue: EncounterService { EncounterService() }
}

extension DependencyValues {
    var encounterService: EncounterService {
        get { self[EncounterService.self] }
        set { self[EncounterService.self] = newValue }
    }
}
