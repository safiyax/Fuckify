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
    @State private var partnerForEncounter: Partner?
    @State private var selectedPartner: Partner?
    @State private var showingAddPartner = false
    @State private var showingSettings = false
    

    var body: some View {
        @Bindable var manager = manager
        NavigationStack {
            List {
                // Pinned Partners Section
                if !manager.pinnedPartners.isEmpty {
                    Section {
                        HStack {
                            Spacer()
                            if manager.pinnedPartners.count == 1 {
                                ForEach(manager.pinnedPartners) { partner in
                                    PinnedPartnerView(
                                        partner: partner,
                                        onAddEncounter: { partnerForEncounter = partner },
                                        onTap: { selectedPartner = partner }
                                    )
                                    .buttonStyle(.plain)
                                }
                            } else {
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(manager.pinnedPartners) { partner in
                                        PinnedPartnerView(
                                            partner: partner,
                                            onAddEncounter: { partnerForEncounter = partner },
                                            onTap: { selectedPartner = partner }
                                        )
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                // Main List
                Section {
                    ForEach(manager.filteredPartners) { partner in
                        NavigationLink {
                            PartnerDetailView(partner: partner)
                        } label: {
                            PartnerRowView(partner: partner)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                withAnimation {
                                    manager.togglePin(for: partner)
                                }
                            } label: {
                                Label("Pin", systemImage: "pin.fill")
                            }
                            .tint(.orange)
                        }
                    }
                    .onDelete(perform: deletePartners)
                }
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
            .sheet(item: $partnerForEncounter) { partner in
                EncounterFormView(preselectedPartner: partner)
            }
            .navigationDestination(item: $selectedPartner) { partner in
                PartnerDetailView(partner: partner)
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

// MARK: - Pinned Partner View

struct PinnedPartnerView: View {
    let partner: Partner
    let onAddEncounter: () -> Void
    let onTap: () -> Void
    @Environment(PartnersManager.self) var manager

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(partner.color)
                    .frame(width: 96, height: 96)

                Text(partner.initials)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .glassEffect()
            .overlay(alignment: .bottomTrailing) {
                // Pin indicator
                Image(systemName: "pin.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)
                    .padding(5)
                    .glassEffect()
//                    .background(Circle().fill(Color.orange))
                    .offset(x: 3, y: 3)
            }

            Text(partner.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 96, height: 48, alignment: .top)
        }
        .onTapGesture {
            onTap()
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
