//
//  PartnersManager.swift
//  Fuckify
//
//  ViewModel for partners list and operations
//  Manages presentation state, filtering (pinned/unpinned), and partner CRUD operations
//

import Foundation

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnersViewModel")

/// ViewModel for managing partners list UI state and operations
/// Provides presentation logic, search filtering, pinning, and error handling for partner-related views
/// Uses optimistic updates for better UX (updates UI immediately, rolls back on error)
@MainActor
@Observable
final class PartnersViewModel {
    // MARK: - Dependencies
    
    private let partnerService: PartnerService
    
    // MARK: - Published State

    var partners: [SQLPartner] = []
    var searchText: String = ""
    var errorMessage: String?
    var isLoading = false

    // MARK: - Initialization
    
    /// Initialize with dependency injection for testability
    /// - Parameter partnerService: Service for partner database operations (defaults to live implementation)
    nonisolated init(partnerService: PartnerService = PartnerService()) {
        self.partnerService = partnerService
    }

    // MARK: - Data Operations

    func fetchPartners() async {
        isLoading = true
        errorMessage = nil
        
        do {
            partners = try partnerService.fetchAll()
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
            let createdPartner = try partnerService.create(partner)
            logger.info("Created partner: \(createdPartner.id)")
            
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
                try partnerService.update(partner)
                logger.info("Updated partner: \(partner.id)")
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
            try partnerService.delete(partner.id)
            logger.info("Deleted partner: \(partner.id)")
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
                try partnerService.togglePin(for: partner.id)
                logger.info("Toggled pin for partner: \(partner.id)")
            } catch {
                // Rollback on error
                partners[index].isPinned = oldValue
                logger.error("Failed to toggle pin: \(error.localizedDescription)")
                errorMessage = "Unable to update pin status. Please try again."
            }
        }
    }
}

// MARK: - Type Alias for Backward Compatibility

/// Backward compatibility alias - prefer using PartnersViewModel
@available(*, deprecated, renamed: "PartnersViewModel", message: "Use PartnersViewModel instead")
typealias PartnersManager = PartnersViewModel
