//
//  ContentView.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import SwiftUI
import SwiftData
import SQLiteData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("selectedTab") var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Activity", systemImage: "heart.fill", value: 0) {
                EncountersListView()
            }

            Tab("Partners", systemImage: "person.2.fill", value: 1) {
                PartnersListView()
                    .environment(PartnersManager(modelContext: self.modelContext))
            }

            Tab("Summary", systemImage: "circle.hexagonpath.fill", value: 2) {
                StatisticsView()
            }

       
            Tab("Search", systemImage: "magnifyingglass", value: 5, role: .search) {
                withAnimation {
                    PartnersListView()
                        .environment(PartnersManager(modelContext: self.modelContext))
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Partner.self, inMemory: true)
}
