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
    @State private var encountersManager = EncountersManager()
    @State private var profile = UserProfile.shared
    @State private var showingActiveEncounter = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Activity", systemImage: "bed.double", value: 0) {
//                EncountersListView()
                CalendarView()
                    .environment(encountersManager)
            }
            
            Tab("Summary", systemImage: "chart.pie.fill", value: 2) {
                StatisticsView()
                    .environment(encountersManager)
            }

            Tab("Partners", systemImage: "bolt.heart", value: 1) {
                PartnersListView()
                    .environment(partnersManager)
            }

            Tab("Profile", systemImage: "person.crop.circle", value: 3) {
                ProfileView()
            }


            Tab("Search", systemImage: "magnifyingglass", value: 5, role: .search) {
                withAnimation {
                    PartnersListView()
                        .environment(partnersManager)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .sheet(isPresented: $showingActiveEncounter) {
            ActiveEncounterView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showActiveEncounter"))) { _ in
            showingActiveEncounter = true
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return ContentView()
}
