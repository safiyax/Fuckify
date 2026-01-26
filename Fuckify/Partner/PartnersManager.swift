//
//  PartnersManager.swift
//  Fuckify
//
//  Manager for partner operations using SQLite services
//

import Foundation
import Dependencies
import OSLog

private let logger = Logger(subsystem: "com.fuckify", category: "PartnersManager")

@MainActor
@Observable
class PartnersManager {
    @ObservationIgnored
    @Dependency(\.partnerService) private var partnerService

    var partners: [SQLPartner] = []
    var searchText: String = ""
    var errorMessage: String?
    var isLoading = false

    init() {
        // Don't fetch in init - let views trigger it
    }

    // MARK: - Data Operations

    func fetchPartners() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = partnerService
            
            // Perform database I/O off main thread
            let fetchedPartners = try await Task.detached {
                try await service.fetchAll()
            }.value
            
            // Update UI on main thread
            partners = fetchedPartners
            logger.info("Fetched \(self.partners.count) partners")
        } catch {
            logger.error("Failed to fetch partners: \(error.localizedDescription)")
            errorMessage = "Unable to load partners. Please try again."
            partners = []
        }
        
        isLoading = false
    }

    func addPartner(_ partner: SQLPartner.Draft) async {
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = partnerService
            
            let createdPartner = try await Task.detached {
                try await service.create(partner)
            }.value
            logger.info("Created partner: \(partner.name)")
            
            // Optimistic update - add to list immediately
            partners.append(createdPartner)
            partners.sort { $0.name < $1.name }
        } catch {
            logger.error("Failed to create partner: \(error.localizedDescription)")
            errorMessage = "Unable to create partner. Please try again."
        }
    }

    func updatePartner(_ partner: SQLPartner) async {
        // Optimistic update
        if let index = partners.firstIndex(where: { $0.id == partner.id }) {
            let oldPartner = partners[index]
            partners[index] = partner
            
            do {
                // Capture service before detached task to avoid actor isolation issues
                let service = partnerService
                
                try await Task.detached {
                    try await service.update(partner)
                }.value
                logger.info("Updated partner: \(partner.name)")
            } catch {
                // Rollback on error
                partners[index] = oldPartner
                logger.error("Failed to update partner: \(error.localizedDescription)")
                errorMessage = "Unable to update partner. Please try again."
            }
        }
    }

    func deletePartner(_ partner: SQLPartner) async {
        // Optimistic update
        guard let index = partners.firstIndex(where: { $0.id == partner.id }) else { return }
        let removedPartner = partners.remove(at: index)
        
        do {
            // Capture service before detached task to avoid actor isolation issues
            let service = partnerService
            
            try await Task.detached {
                try await service.delete(partner.id)
            }.value
            logger.info("Deleted partner: \(partner.name)")
        } catch {
            // Rollback on error
            partners.insert(removedPartner, at: index)
            logger.error("Failed to delete partner: \(error.localizedDescription)")
            errorMessage = "Unable to delete partner. Please try again."
        }
    }

    func deletePartners(at offsets: IndexSet, from filteredList: [SQLPartner]) async {
        // Capture IDs to avoid index issues
        let partnersToDelete = offsets.map { filteredList[$0] }
        
        for partner in partnersToDelete {
            await deletePartner(partner)
        }
    }

    // MARK: - Computed Properties

    var pinnedPartners: [SQLPartner] {
        partners.filter { $0.isPinned }
    }

    var unpinnedPartners: [SQLPartner] {
        partners.filter { !$0.isPinned }
    }

    var filteredPartners: [SQLPartner] {
        let baseList = unpinnedPartners  // Only show unpinned in main list
        if searchText.isEmpty {
            return baseList
        }
        return baseList.filter { partner in
            partner.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var partnerCount: Int {
        partners.count
    }

    // MARK: - Pin Operations

    func togglePin(for partner: SQLPartner) async {
        // Optimistic update
        if let index = partners.firstIndex(where: { $0.id == partner.id }) {
            var updatedPartner = partners[index]
            let oldValue = updatedPartner.isPinned
            updatedPartner.isPinned.toggle()
            partners[index] = updatedPartner
            
            do {
                // Capture service before detached task to avoid actor isolation issues
                let service = partnerService
                
                try await Task.detached {
                    try await service.togglePin(for: partner.id)
                }.value
                logger.info("Toggled pin for partner: \(partner.name)")
            } catch {
                // Rollback on error
                partners[index].isPinned = oldValue
                logger.error("Failed to toggle pin: \(error.localizedDescription)")
                errorMessage = "Unable to update pin status. Please try again."
            }
        }
    }
}

// MARK: - Dependency Key

extension PartnerService: DependencyKey {
    static var liveValue: PartnerService { PartnerService() }
}

extension DependencyValues {
    var partnerService: PartnerService {
        get { self[PartnerService.self] }
        set { self[PartnerService.self] = newValue }
    }
}
