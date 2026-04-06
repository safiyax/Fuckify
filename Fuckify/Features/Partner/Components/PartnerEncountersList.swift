//
//  PartnerEncountersList.swift
//  Fuckify
//
//  List of encounters for a specific partner
//

import SwiftUI
import SQLiteData

struct PartnerEncountersList: View {
    let encounters: [SQLEncounter]
    
    var sortedEncounters: [SQLEncounter] {
        encounters.sorted(by: {
            guard let date1 = $0.date, let date2 = $1.date else { return false }
            return date1 > date2
        })
    }
    
    var body: some View {
        Section {
            if !sortedEncounters.isEmpty {
                ForEach(sortedEncounters) { encounter in
                    NavigationLink {
                        EncounterDetailView(encounter: encounter)
                    } label: {
                        EncounterRowView(encounter: encounter)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "heart.slash")
                        .foregroundStyle(.secondary)
                    Text("No encounters yet")
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("No encounters recorded with this partner")
            }
        } header: {
            HStack {
                Text("Encounters")
                if !sortedEncounters.isEmpty {
                    Text("(\(sortedEncounters.count))")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        List {
            PartnerEncountersList(encounters: [])
        }
    }
}
