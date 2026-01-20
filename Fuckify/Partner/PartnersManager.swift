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

@Observable
class PartnersManager {
    @ObservationIgnored
    @Dependency(\.partnerService) private var partnerService

    var partners: [SQLPartner] = []
    var searchText: String = ""
    var errorMessage: String?
    var isLoading = false

    init() {
        fetchPartners()
    }

    // MARK: - Data Operations

    func fetchPartners() {
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

    func addPartner(_ partner: SQLPartner.Draft) {
        do {
            try partnerService.create(partner)
            logger.info("Created partner: \(partner.name)")
            fetchPartners()
        } catch {
            logger.error("Failed to create partner: \(error.localizedDescription)")
            errorMessage = "Unable to create partner. Please try again."
        }
    }

    func updatePartner(_ partner: SQLPartner) {
        do {
            try partnerService.update(partner)
            logger.info("Updated partner: \(partner.name)")
            fetchPartners()
        } catch {
            logger.error("Failed to update partner: \(error.localizedDescription)")
            errorMessage = "Unable to update partner. Please try again."
        }
    }

    func deletePartner(_ partner: SQLPartner) {
        do {
            try partnerService.delete(partner.id)
            logger.info("Deleted partner: \(partner.name)")
            fetchPartners()
        } catch {
            logger.error("Failed to delete partner: \(error.localizedDescription)")
            errorMessage = "Unable to delete partner. Please try again."
        }
    }

    func deletePartners(at offsets: IndexSet, from filteredList: [SQLPartner]) {
        for index in offsets {
            deletePartner(filteredList[index])
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

    func togglePin(for partner: SQLPartner) {
        do {
            try partnerService.togglePin(for: partner.id)
            logger.info("Toggled pin for partner: \(partner.name)")
            fetchPartners()
        } catch {
            logger.error("Failed to toggle pin: \(error.localizedDescription)")
            errorMessage = "Unable to update pin status. Please try again."
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
