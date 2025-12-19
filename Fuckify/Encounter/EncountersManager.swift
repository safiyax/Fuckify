//
//  EncountersManager.swift
//  Fuckify
//
//

import Foundation
import SwiftData

@Observable
class EncountersManager {
    private var modelContext: ModelContext

    var encounters: [Encounter] = []
    var searchText: String = ""

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchEncounters()
    }

    // MARK: - Data Operations

    func fetchEncounters() {
        let descriptor = FetchDescriptor<Encounter>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            encounters = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch encounters: \(error)")
            encounters = []
        }
    }

    func addEncounter(_ encounter: Encounter) {
        modelContext.insert(encounter)
        fetchEncounters()
    }

    func deleteEncounter(_ encounter: Encounter) {
        modelContext.delete(encounter)
        fetchEncounters()
    }

    func deleteEncounters(at offsets: IndexSet, from filteredList: [Encounter]) {
        for index in offsets {
            modelContext.delete(filteredList[index])
        }
        fetchEncounters()
    }

    // MARK: - Computed Properties

    var filteredEncounters: [Encounter] {
        if searchText.isEmpty {
            return encounters
        }
        return encounters.filter { encounter in
            encounter.partnerNames.localizedCaseInsensitiveContains(searchText) ||
            encounter.location.localizedCaseInsensitiveContains(searchText) ||
            encounter.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    var encounterCount: Int {
        encounters.count
    }
}
