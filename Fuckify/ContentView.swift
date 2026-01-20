//
//  ContentView.swift
//  Fuckify
//
//  Updated to use SQLite services
//

import SwiftUI
import SQLiteData

struct ContentView: View {
    @SceneStorage("selectedTab") var selectedTab = 0
    @State private var partnersManager = PartnersManager()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Activity", systemImage: "heart.fill", value: 0) {
                EncountersListView()
            }

            Tab("Partners", systemImage: "person.2.fill", value: 1) {
                PartnersListView()
                    .environment(partnersManager)
            }

            Tab("Summary", systemImage: "circle.hexagonpath.fill", value: 2) {
                StatisticsView()
            }

            Tab("Search", systemImage: "magnifyingglass", value: 5, role: .search) {
                withAnimation {
                    PartnersListView()
                        .environment(partnersManager)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return ContentView()
}
