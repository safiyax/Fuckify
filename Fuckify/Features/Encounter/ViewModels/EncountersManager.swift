//
//  EncountersManager.swift
//  Fuckify
//
//  ViewModel for encounters list and operations
//  Manages presentation state, filtering, and coordinates encounter/partner services
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "EncountersViewModel")

/// ViewModel for managing encounters list UI state and operations
/// Provides presentation logic, search filtering, and error handling for encounter-related views
@MainActor
@Observable
final class EncountersViewModel {
    // MARK: - Dependencies
    
    private let encounterService: EncounterService
    private let partnerService: PartnerService
    
    // MARK: - Published State
    
    var encountersWithRelationships: [EncounterWithRelationships] = []
    var searchText: String = ""
    var errorMessage: String?
    var isLoading = false
    var positionTypes: [SQLPositionType] = []
    
    // MARK: - Computed Properties
    
    /// Convenience accessor for just encounters (without relationships)
    var encounters: [SQLEncounter] {
        encountersWithRelationships.map(\.encounter)
    }

    // MARK: - Initialization
    
    /// Initialize with dependency injection for testability
    /// - Parameters:
    ///   - encounterService: Service for encounter database operations (defaults to live implementation)
    ///   - partnerService: Service for partner database operations (defaults to live implementation)
    nonisolated init(
        encounterService: EncounterService = EncounterService(),
        partnerService: PartnerService = PartnerService()
    ) {
        self.encounterService = encounterService
        self.partnerService = partnerService
    }

    // MARK: - Data Operations

    func fetchEncounters() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Perform database I/O with batch loading
            // This loads all encounters with their relationships in just 4 queries
            // instead of 3N+1 queries (where N = number of encounters)
            encountersWithRelationships = try encounterService.fetchAllWithRelationships()
            positionTypes = (try? PositionTypeService().fetchAll()) ?? []
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
        partnerPositionTypeIDs: [UUID: UUID?] = [:],
        partnerOrgasms: [UUID: Bool] = [:],
        myPositionTypeId: UUID? = nil,
        activityTypeIDs: [UUID],
        protectionMethodIDs: [UUID]
    ) async {
        do {
            let encounterID = try encounterService.create(
                encounterDraft,
                partnerIDs: partnerIDs,
                partnerPositionTypeIDs: partnerPositionTypeIDs,
                partnerOrgasms: partnerOrgasms,
                myPositionTypeId: myPositionTypeId,
                activityTypeIDs: activityTypeIDs,
                protectionMethodIDs: protectionMethodIDs
            )
            logger.info("Created encounter: \(encounterID)")
            await fetchEncounters()
        } catch {
            logger.error("Failed to create encounter: \(error.localizedDescription)")
            errorMessage = "Unable to create encounter. Please try again."
        }
    }

    func updateEncounter(
        _ encounter: SQLEncounter,
        partnerIDs: [UUID]? = nil,
        partnerPositionTypeIDs: [UUID: UUID?]? = nil,
        partnerOrgasms: [UUID: Bool]? = nil,
        myPositionTypeId: UUID?? = nil,
        activityTypeIDs: [UUID]? = nil,
        protectionMethodIDs: [UUID]? = nil
    ) async {
        do {
            try encounterService.update(
                encounter,
                partnerIDs: partnerIDs,
                partnerPositionTypeIDs: partnerPositionTypeIDs,
                partnerOrgasms: partnerOrgasms,
                myPositionTypeId: myPositionTypeId,
                activityTypeIDs: activityTypeIDs,
                protectionMethodIDs: protectionMethodIDs
            )
            logger.info("Updated encounter: \(encounter.id)")
            await fetchEncounters()
        } catch {
            logger.error("Failed to update encounter: \(error.localizedDescription)")
            errorMessage = "Unable to update encounter. Please try again."
        }
    }

    func deleteEncounter(_ encounter: SQLEncounter) async {
        do {
            try encounterService.delete(encounter.id)
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
            return try encounterService.fetchPartners(for: encounter.id)
        } catch {
            logger.error("Failed to fetch partners for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get activity entities for a specific encounter (NEW: UUID-based)
    func activityEntities(for encounter: SQLEncounter) async -> [SQLActivityTypeEntity] {
        do {
            return try encounterService.fetchActivityEntities(for: encounter.id)
        } catch {
            logger.error("Failed to fetch activities for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Get protection method entities for a specific encounter (NEW: UUID-based)
    func protectionMethodEntities(for encounter: SQLEncounter) async -> [SQLProtectionMethodEntity] {
        do {
            return try encounterService.fetchProtectionMethodEntities(for: encounter.id)
        } catch {
            logger.error("Failed to fetch protection methods for encounter: \(error.localizedDescription)")
            return []
        }
    }
    
}

// MARK: - Type Alias for Backward Compatibility

/// Backward compatibility alias - prefer using EncountersViewModel
@available(*, deprecated, renamed: "EncountersViewModel", message: "Use EncountersViewModel instead")
typealias EncountersManager = EncountersViewModel
