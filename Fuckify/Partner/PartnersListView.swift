//
//  PartnersListView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct PartnersListView: View {
    @Environment(\.modelContext) private var modelContext
    @SceneStorage("selectedTab") var selectedTab = 1
    @State private var manager: PartnersManager?
    @State private var showingAddPartner = false
    @State private var showingSettings = false

    private var filteredPartners: [Partner] {
        manager?.filteredPartners ?? []
    }

    private var partners: [Partner] {
        manager?.partners ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredPartners) { partner in
                    NavigationLink {
                        PartnerDetailView(partner: partner)
                    } label: {
                        PartnerRowView(partner: partner)
                    }
                }
                .onDelete(perform: deletePartners)
            }
            .onAppear {
                if manager == nil {
                    manager = PartnersManager(modelContext: modelContext)
                }
                // Clear search when view appears
                manager?.searchText = ""
            }
            .navigationTitle("Partners")
            .isSearchable(selectedTab: selectedTab, searchText: Binding(
                get: { manager?.searchText ?? "" },
                set: { manager?.searchText = $0 }
            ))
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
                    manager?.fetchPartners()
                }
            }
            .overlay {
                if partners.isEmpty {
                    ContentUnavailableView(
                        "No Partners",
                        systemImage: "person.2.slash",
                        description: Text("Add a partner to get started")
                    )
                } else if filteredPartners.isEmpty {
                    ContentUnavailableView.search
                }
            }
        }
    }

    private func deletePartners(offsets: IndexSet) {
        withAnimation {
            manager?.deletePartners(at: offsets, from: filteredPartners)
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
        if selectedTab == 1 {
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
