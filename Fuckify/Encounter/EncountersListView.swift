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

struct EncountersListView: View {
    @Environment(EncountersManager.self) var manager
    @Dependency(\.encounterService) var encounterService
    
    @State private var showingAddEncounter = false
    @State private var showingSettings = false
    @State private var showProfile = false
    @State private var profile = UserProfile.shared
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
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if #available(iOS 26.0, *) {
                        Button(action: { showProfile = true }) {
                            ZStack {
                                Text(profile.initials)
                            }
                        }
                        .buttonStyle(.glassProminent)
                    } else {
                        Button(action: { showProfile = true }) {
                            ZStack {
                                Text(profile.initials)
                            }
                        }
                        .buttonStyle(.compatibleGlassProminent)
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
    @State private var loadedActivities: [SQLActivityType] = []
    @State private var loadedProtectionMethods: [SQLProtectionMethod] = []
    
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
    
    private var activities: [SQLActivityType] {
        encounterData?.activities ?? loadedActivities
    }
    
    private var protectionMethods: [SQLProtectionMethod] {
        encounterData?.protectionMethods ?? loadedProtectionMethods
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
                if !activities.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(activities.prefix(3), id: \.self) { activity in
                            Image(systemName: activity.icon)
                                .foregroundColor(.purple)
                                .font(.caption)
                        }
                        if activities.count > 3 {
                            Text("+\(activities.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                if !protectionMethods.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(protectionMethods.prefix(2), id: \.self) { protection in
                            Image(systemName: protection.icon)
                                .foregroundColor(.green)
                                .font(.caption)
                        }
                    }
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
    
    private func loadRelationships() async {
        // Capture service before detached task to avoid actor isolation issues
        let service = encounterService
        let encounterId = encounter.id
        
        do {
            let partners = try await Task.detached {
                try service.fetchPartners(for: encounterId)
            }.value
            loadedPartners = partners
            
            let activities = try await Task.detached {
                try service.fetchActivities(for: encounterId)
            }.value
            loadedActivities = activities
            
            let protectionMethods = try await Task.detached {
                try service.fetchProtectionMethods(for: encounterId)
            }.value
            loadedProtectionMethods = protectionMethods
        } catch {
            // Silent fail - relationships will be empty
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
