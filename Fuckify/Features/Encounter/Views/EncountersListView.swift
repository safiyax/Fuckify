//
//  EncountersListView.swift
//  Fuckify
//
//  Encounters list using SQLiteData
//

import SwiftUI
import SQLiteData
import Dependencies
import MijickCalendarView

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "EncountersListView")

struct EncountersListView: View {
    @Environment(EncountersViewModel.self) var manager
    @Dependency(\.encounterService) var encounterService
    
    @State private var showingAddEncounter = false
    @State private var showingSettings = false
    @State private var showProfile = false
    @Environment(UserProfile.self) private var profile
    @State private var selectedDate: Date? = nil
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(manager.filteredEncounters) { encounterData in
                     NavigationLink {
                         EncounterDetailView(encounter: encounterData.encounter)
                     } label: {
                        EncounterRowView(encounterData: encounterData)
                     }
                }
                .onDelete(perform: deleteEncounters)
            }
            .task {
                await manager.fetchEncounters()
            }
            .navigationTitle("Activity")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { showingAddEncounter = true }) {
                        Label("Add Encounter", systemImage: "plus")
                    }
                    .accessibilityHint("Opens form to log a new encounter")
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if #available(iOS 26.0, *) {
                        Button(action: { showProfile = true }) {
                            ZStack {
                                Text(profile.initials)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityLabel("View profile")
                        .accessibilityHint("Shows your profile settings")
                    } else {
                        Button(action: { showProfile = true }) {
                            ZStack {
                                Text(profile.initials)
                            }
                        }
                        .buttonStyle(.compatibleGlassProminent)
                        .accessibilityLabel("View profile")
                        .accessibilityHint("Shows your profile settings")
                    }
                }
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showingAddEncounter) {
                EncounterFormView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showProfile, content: {
                ProfileView()
            })
            .overlay {
                if manager.encounters.isEmpty {
                    ContentUnavailableView(
                        "No Encounters",
                        systemImage: "heart.slash",
                        description: Text("Add an encounter to get started")
                    )
                }
            }
        }
    }

    private func deleteEncounters(offsets: IndexSet) {
        Task {
            await manager.deleteEncounters(at: offsets, from: manager.filteredEncounters.map(\.encounter))
        }
    }
}

// MARK: - Encounter Row View

struct EncounterRowView: View {
    let encounterData: EncounterWithRelationships?
    let encounter: SQLEncounter
    
    @Dependency(\.encounterService) var encounterService
    @State private var loadedPartners: [SQLPartner] = []
    @State private var loadedActivityEntities: [SQLActivityTypeEntity] = []           // NEW
    @State private var loadedProtectionEntities: [SQLProtectionMethodEntity] = []    // NEW
    
    // Convenience initializer for batch-loaded data (preferred)
    init(encounterData: EncounterWithRelationships) {
        self.encounterData = encounterData
        self.encounter = encounterData.encounter
    }
    
    // Legacy initializer for backward compatibility (will load on demand)
    init(encounter: SQLEncounter) {
        self.encounterData = nil
        self.encounter = encounter
    }
    
    private var partners: [SQLPartner] {
        encounterData?.partners ?? loadedPartners
    }
    
    private var activityEntities: [SQLActivityTypeEntity] {
        encounterData?.activityEntities ?? loadedActivityEntities
    }
    
    private var protectionEntities: [SQLProtectionMethodEntity] {
        encounterData?.protectionEntities ?? loadedProtectionEntities
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Date and Duration
            HStack {
                if let date = encounter.date {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                } else {
                    Text("No date")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if encounter.duration > 0 {
                    Text(encounter.formattedDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            // Partners
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.blue)
                    .font(.caption)

                Text(partnerNames)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Activities and Protection
            HStack(spacing: 12) {
                if !activityEntities.isEmpty {
                    EntityIconRow(
                        entities: activityEntities.map { (icon: $0.icon, name: $0.name) },
                        color: .purple,
                        maxShown: 3,
                        font: .caption
                    )
                    .accessibilityElement(children: .combine)
                }

                if !protectionEntities.isEmpty {
                    EntityIconRow(
                        entities: protectionEntities.map { (icon: $0.icon, name: $0.name) },
                        color: .green,
                        maxShown: 2,
                        font: .caption
                    )
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.vertical, 4)
        .task {
            // Only load if data wasn't pre-loaded (legacy mode)
            if encounterData == nil {
                await loadRelationships()
            }
        }
    }
    
    @MainActor
    private func loadRelationships() async {
        do {
            loadedPartners = try encounterService.fetchPartners(for: encounter.id)
            loadedActivityEntities = try encounterService.fetchActivityEntities(for: encounter.id)              // NEW
            loadedProtectionEntities = try encounterService.fetchProtectionMethodEntities(for: encounter.id)   // NEW
        } catch {
            logger.error("Failed to load relationships for encounter \(encounter.id): \(error.localizedDescription)")
        }
    }
    
    private var partnerNames: String {
        guard !partners.isEmpty else { return "No partners" }
        return partners.map(\.name).joined(separator: ", ")
    }
}

//struct EncounterCalendarView: View {
//    @Binding var selectedDate: Date?
//    @Binding var selectedMonth: Date
//    
//    var body: some View {
//        MCalendarView(selectedDate: $selectedDate, selectedRange: nil)
//    }
//    
//    func configureCalendar(_ config: CalendarConfig) -> CalendarConfig {
//        config
//            .monthsTopPadding(36)
//            .monthsBottomPadding(8)
//            .daysHorizontalSpacing(1)
//            .daysVerticalSpacing(3)
//            .startMonth(selectedMonth)
//            .endMonth(selectedMonth)
//            .dayView()
//    }
//    
//    func buildDayView(_ date: Date, _ isCurrentMonth: Bool, selectedDate: Binding<Date?>?, range: Binding<MDateRange?>?) -> DV.ColoredCircle {
//
//    }
//}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return EncountersListView()
}
