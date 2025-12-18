//
//  PartnersListView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PartnersManager.self) var manager
    @SceneStorage("selectedTab") var selectedTab = 1
    @State private var showingAddPartner = false
    @State private var showingSettings = false
    

    var body: some View {
        @Bindable var manager = manager
        NavigationStack {
            List {
                ForEach(manager.filteredPartners) { partner in
                    NavigationLink {
                        PartnerDetailView(partner: partner)
                    } label: {
                        PartnerRowView(partner: partner)
                    }
                }
                .onDelete(perform: deletePartners)
            }
            .onAppear {
                manager.searchText = ""
            }
            .navigationTitle("Partners")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: { showingAddPartner = true }) {
                        Label("Add Partner", systemImage: "plus")
                    }
                }
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showingAddPartner) {
                PartnerFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .onChange(of: showingAddPartner) { oldValue, newValue in
                if !newValue {
                    manager.fetchPartners()
                }
            }
            .overlay {
                if manager.partners.isEmpty {
                    ContentUnavailableView(
                        "No Partners",
                        systemImage: "person.2.slash",
                        description: Text("Add a partner to get started")
                    )
                } else if manager.filteredPartners.isEmpty {
                    ContentUnavailableView.search
                }
            }
            .isSearchable(selectedTab: selectedTab, searchText: $manager.searchText)
        }
    }

    private func deletePartners(offsets: IndexSet) {
        withAnimation {
            manager.deletePartners(at: offsets, from: manager.filteredPartners)
        }
    }
}

// MARK: - Partner Row View

struct PartnerRowView: View {
    let partner: Partner

    var body: some View {
        HStack(spacing: 12) {
            // Initials Avatar
            ZStack {
                Circle()
                    .fill(partner.color)
                    .frame(width: 50, height: 50)

                Text(partner.initials)
                    .font(.headline)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(partner.name)
                    .font(.headline)

                HStack {
                    Text(partner.relationshipType.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if partner.isOnPrep {
                        Text("• PrEP")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }

                if let lastEncounter = partner.lastEncounterDate {
                    Text("Last: \(lastEncounter.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - View Modifier

struct IsSearchable: ViewModifier {
    let selectedTab: Int
    @Binding var searchText: String

    func body(content: Content) -> some View {
        if selectedTab == 5 {
            content
                .searchable(text: $searchText, prompt: "Search partners")
        } else {
            content
        }
    }
}

extension View {
    func isSearchable(selectedTab: Int, searchText: Binding<String>) -> some View {
        modifier(IsSearchable(selectedTab: selectedTab, searchText: searchText))
    }
}

#Preview {
    TabView {
        PartnersListView()
            .tabItem {
                Label("partners", systemImage: "person.3.fill")
            }
    }
}
