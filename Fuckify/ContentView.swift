//
//  ContentView.swift
//  Fuckify
//
//  Created by Safiya Hooda on 2025-11-08.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            EncountersListView()
                .tabItem {
                    Label("Activity", systemImage: "heart.fill")
                }

            PartnersListView()
                .tabItem {
                    Label("Partners", systemImage: "person.3.fill")
                }

            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.text.rectangle.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Partner.self, inMemory: true)
}
