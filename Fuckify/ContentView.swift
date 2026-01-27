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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Activity", systemImage: "bed.double", value: 0) {
//                EncountersListView()
                CalendarView()
                    .environment(encountersManager)
            }
            
            Tab("Summary", systemImage: "chart.bar.xaxis", value: 2) {
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
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return ContentView()
}
