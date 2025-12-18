//
//  PartnersManager.swift
//  Fuckify
//
//

import Foundation
import SwiftData

@Observable
class PartnersManager {
    private var modelContext: ModelContext

    var partners: [Partner] = []
    var searchText: String = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchPartners()
    }

    // MARK: - Data Operations

    func fetchPartners() {
        let descriptor = FetchDescriptor<Partner>(sortBy: [SortDescriptor(\.name)])
        do {
            partners = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch partners: \(error)")
            partners = []
        }
    }

    func addPartner(_ partner: Partner) {
        modelContext.insert(partner)
        fetchPartners()
    }

    func deletePartner(_ partner: Partner) {
        modelContext.delete(partner)
        fetchPartners()
    }

    func deletePartners(at offsets: IndexSet, from filteredList: [Partner]) {
        for index in offsets {
            modelContext.delete(filteredList[index])
        }
        fetchPartners()
    }

    // MARK: - Computed Properties

    var filteredPartners: [Partner] {
        if searchText.isEmpty {
            return partners
        }
        return partners.filter { partner in
            partner.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var partnerCount: Int {
        partners.count
    }
}
