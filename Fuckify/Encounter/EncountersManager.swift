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

@MainActor
@Observable
class EncountersManager {
    @ObservationIgnored
    @Dependency(\.encounterService) private var encounterService
    
    @ObservationIgnored
    @Dependency(\.partnerService) private var partnerService

    var encountersWithRelationships: [EncounterWithRelationships] = []
    var searchText: String = ""
    var errorMessage: String?
    var isLoading = false
    
    // Convenience accessor for just encounters
    var encounters: [SQLEncounter] {
        encountersWithRelationships.map(\.encounter)
    }

    init() {
        // Don't fetch in init - let views trigger it
    }

    // MARK: - Data Operations

    func fetchEncounters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = encounterService
            
            // Perform database I/O off main thread with batch loading
            // This loads all encounters with their relationships in just 4 queries
            // instead of 3N+1 queries (where N = number of encounters)
            let fetchedEncounters = try await Task.detached {
                try service.fetchAllWithRelationships()
            }.value
            
            // Update UI on main thread
            encountersWithRelationships = fetchedEncounters
            logger.info("Fetched \(self.encounters.count) encounters with relationships")
        } catch {
            logger.error("Failed to fetch encounters: \(error.localizedDescription)")
            errorMessage = "Unable to load encounters. Please try again."
            encountersWithRelationships = []
        }
        
        isLoading = false
    }

    func addEncounter(
        _ encounterDraft: SQLEncounter.Draft,
        partnerIDs: [UUID],
        activities: [SQLActivityType],
        protectionMethods: [SQLProtectionMethod]
    ) async {
        do {
            // Capture services before detached task to avoid actor isolation issues
            let encService = encounterService
            let pService = partnerService
            
            let encounterID = try await Task.detached {
                try encService.create(
                    encounterDraft,
                    partnerIDs: partnerIDs,
                    activities: activities,
                    protectionMethods: protectionMethods
                )
            }.value
            logger.info("Created encounter: \(encounterID)")
            
            // Update last encounter date for all partners
            if let date = encounterDraft.date {
                for partnerID in partnerIDs {
                    try? await Task.detached {
                        try pService.updateLastEncounterDate(partnerID, date: date)
                    }.value
                }
            }
            
            // Refresh the list
            await fetchEncounters()
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
    ) async {
        do {
            // Capture services before detached task to avoid actor isolation issues
            let encService = encounterService
            let pService = partnerService
            
            // Perform database I/O off main thread
            try await Task.detached {
                try encService.update(
                    encounter,
                    partnerIDs: partnerIDs,
                    activities: activities,
                    protectionMethods: protectionMethods
                )
            }.value
            logger.info("Updated encounter: \(encounter.id)")
            
            // Update last encounter date for partners if date changed
            if let date = encounter.date, let partnerIDs = partnerIDs {
                for partnerID in partnerIDs {
                    try? await Task.detached {
                        try pService.updateLastEncounterDate(partnerID, date: date)
                    }.value
                }
            }
            
            // Refresh the list
            await fetchEncounters()
        } catch {
            logger.error("Failed to update encounter: \(error.localizedDescription)")
            errorMessage = "Unable to update encounter. Please try again."
        }
    }

    func deleteEncounter(_ encounter: SQLEncounter) async {
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = encounterService
            
            // Perform database I/O off main thread
            try await Task.detached {
                try service.delete(encounter.id)
            }.value
            logger.info("Deleted encounter: \(encounter.id)")
            
            // Refresh the list
            await fetchEncounters()
        } catch {
            logger.error("Failed to delete encounter: \(error.localizedDescription)")
            errorMessage = "Unable to delete encounter. Please try again."
        }
    }

    func deleteEncounters(at offsets: IndexSet, from filteredList: [SQLEncounter]) async {
        for index in offsets {
            await deleteEncounter(filteredList[index])
        }
    }

    // MARK: - Computed Properties

    var filteredEncounters: [EncounterWithRelationships] {
        if searchText.isEmpty {
            return encountersWithRelationships
        }
        return encountersWithRelationships.filter { item in
            let encounter = item.encounter
            let partnerNames = item.partners.map(\.name).joined(separator: " ")
            
            return encounter.location.localizedCaseInsensitiveContains(searchText) ||
                   encounter.notes.localizedCaseInsensitiveContains(searchText) ||
                   partnerNames.localizedCaseInsensitiveContains(searchText)
        }
    }

    var encounterCount: Int {
        encounters.count
    }
    
    // MARK: - Helper Methods
    
    /// Get partners for a specific encounter
    func partners(for encounter: SQLEncounter) async -> [SQLPartner] {
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = encounterService
            
            return try await Task.detached {
                try service.fetchPartners(for: encounter.id)
            }.value
        } catch {
            logger.error("Failed to fetch partners for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activities for a specific encounter
    func activities(for encounter: SQLEncounter) async -> [SQLActivityType] {
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = encounterService
            
            return try await Task.detached {
                try service.fetchActivities(for: encounter.id)
            }.value
        } catch {
            logger.error("Failed to fetch activities for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get protection methods for a specific encounter
    func protectionMethods(for encounter: SQLEncounter) async -> [SQLProtectionMethod] {
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = encounterService
            
            return try await Task.detached {
                try service.fetchProtectionMethods(for: encounter.id)
            }.value
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
