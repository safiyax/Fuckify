//
//  EncounterFormView.swift
//  Fuckify
//
//  Encounter form using SQLite services
//

import SwiftUI
import SQLiteData
import Dependencies

struct EncounterFormView: View {
    @Dependency(\.encounterService) var encounterService
    @Dependency(\.partnerService) var partnerService
    @Environment(\.dismiss) private var dismiss

    @FetchAll(SQLPartner.order(by: \.name))
    private var allPartners: [SQLPartner]

    var encounter: SQLEncounter?
    var preselectedPartners: [SQLPartner] = []
    var preselectedDate: Date?

    @State private var date: Date = Date()
    @State private var durationHours: Int = 0
    @State private var durationMinutes: Int = 30
    @State private var selectedPartnerIDs: Set<UUID> = []
    @State private var selectedActivityIDs: Set<UUID> = []        // NEW: UUID-based
    @State private var selectedProtectionIDs: Set<UUID> = []      // NEW: UUID-based
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var rating: Int = 0
    @State private var reachedOrgasm: Bool = false
    @Environment(UserSettings.self) private var settings
    @State private var errorMessage: String?
    @State private var showingPartnerPicker = false
    @State private var partnerSearchText = ""
    
    // NEW: Load entities from database
    @State private var availableActivities: [SQLActivityTypeEntity] = []
    @State private var availableProtectionMethods: [SQLProtectionMethodEntity] = []

    var isEditing: Bool {
        encounter != nil
    }
    
    var selectedPartners: [SQLPartner] {
        allPartners.filter { selectedPartnerIDs.contains($0.id) }
    }
    
    var filteredPartners: [SQLPartner] {
        if partnerSearchText.isEmpty {
            return allPartners
        }
        return allPartners.filter { $0.name.localizedCaseInsensitiveContains(partnerSearchText) }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Date and Time
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                    
                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker(selection: $durationHours, label: EmptyView()) {
                            ForEach(0..<24) { hour in
                                Text("\(hour)h").tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Hours")
                        .accessibilityValue("\(durationHours) hours")

                        Picker(selection: $durationMinutes, label: EmptyView()) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Minutes")
                        .accessibilityValue("\(durationMinutes) minutes")
                    }
                }

                // Partners
                Section("Partners") {
                    // Selected partners as chips - using a custom wrapper
                    ChipContainer {
                        ForEach(selectedPartners) { partner in
                            PartnerChip(
                                partner: partner,
                                onRemove: { togglePartner(partner.id) }
                            )
                        }
                        
                        // Add button chip
                        Button {
                            showingPartnerPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.15))
                            .cornerRadius(16)
                        }
                        .accessibilityLabel("Add partner")
                        .accessibilityHint("Opens partner picker to add partners to this encounter")
                    }
                }

                // Activities
                ActivitiesSelectionSection(
                    availableActivities: availableActivities,
                    selectedActivityIDs: $selectedActivityIDs
                )

                // Protection
                ProtectionMethodsSelectionSection(
                    availableProtectionMethods: availableProtectionMethods,
                    selectedProtectionIDs: $selectedProtectionIDs
                )

                // Experience
                RatingSection(rating: $rating, reachedOrgasm: $reachedOrgasm)

                // Location
                Section("Location") {
                    TextField("Location (optional)", text: $location)
                }

                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Encounter" : "Add Encounter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveEncounter()
                        }
                    }
                    .disabled(selectedPartnerIDs.isEmpty)
                }
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showingPartnerPicker) {
                PartnerPickerSheet(
                    allPartners: allPartners,
                    selectedPartnerIDs: $selectedPartnerIDs,
                    searchText: $partnerSearchText
                )
                .dismissOnAppLock()
            }
            .dismissOnAppLock()
        }
    }

    private func loadData() async {
        // Load available activities and protection methods from database
        availableActivities = settings.allActivityTypes()
        availableProtectionMethods = settings.allProtectionMethods()
        
        // Load encounter data if editing
        if let encounter = encounter {
            await loadEncounter(encounter)
        } else {
            // Preselect date if provided
            if let preselectedDate = preselectedDate {
                date = preselectedDate
            }
            
            // Preselect partners if provided
            if !preselectedPartners.isEmpty {
                selectedPartnerIDs = Set(preselectedPartners.map(\.id))
            }
        }
    }

    private func togglePartner(_ partnerID: UUID) {
        if selectedPartnerIDs.contains(partnerID) {
            selectedPartnerIDs.remove(partnerID)
        } else {
            selectedPartnerIDs.insert(partnerID)
        }
    }

    private func loadEncounter(_ encounter: SQLEncounter) async {
        date = encounter.date ?? Date()
        let totalMinutes = Int(encounter.duration / 60)
        durationHours = totalMinutes / 60
        durationMinutes = totalMinutes % 60
        location = encounter.location
        notes = encounter.notes
        rating = encounter.rating
        reachedOrgasm = encounter.reachedOrgasm
        
        // Load relationships (NEW: UUID-based)
        do {
            let partners = try encounterService.fetchPartners(for: encounter.id)
            selectedPartnerIDs = Set(partners.map(\.id))
            
            let activityEntities = try encounterService.fetchActivityEntities(for: encounter.id)
            selectedActivityIDs = Set(activityEntities.map(\.id))
            
            let protectionEntities = try encounterService.fetchProtectionMethodEntities(for: encounter.id)
            selectedProtectionIDs = Set(protectionEntities.map(\.id))
        } catch {
            errorMessage = "Failed to load encounter data"
        }
    }

    @MainActor
    private func saveEncounter() async {
        errorMessage = nil
        
        print("🔍 EncounterFormView: saveEncounter called")
        print("🔍 Partner IDs: \(selectedPartnerIDs)")
        print("🔍 Activity IDs: \(selectedActivityIDs)")
        print("🔍 Protection IDs: \(selectedProtectionIDs)")
        
        let duration = TimeInterval(durationHours * 3600 + durationMinutes * 60)
        let partnerIDs = Array(selectedPartnerIDs)
        let activityTypeIDs = Array(selectedActivityIDs)         // NEW: UUID arrays
        let protectionMethodIDs = Array(selectedProtectionIDs)   // NEW: UUID arrays

        do {
            if let encounter = encounter {
                print("🔍 Editing existing encounter: \(encounter.id)")
                // Edit existing encounter
                var updated = encounter
                updated.date = date
                updated.duration = duration
                updated.location = location
                updated.notes = notes
                updated.rating = rating
                updated.reachedOrgasm = reachedOrgasm
                
                // NEW: Use UUID-based update
                try encounterService.update(
                    updated,
                    partnerIDs: partnerIDs,
                    activityTypeIDs: activityTypeIDs,
                    protectionMethodIDs: protectionMethodIDs
                )
                
                print("🔍 Update successful")
                
                // Update partner last encounter dates
                for partnerID in partnerIDs {
                    try? partnerService.updateLastEncounterDate(partnerID, date: date)
                }
            } else {
                print("🔍 Creating new encounter")
                // Create new encounter
                let draft = SQLEncounter.Draft(
                    id: UUID(),
                    date: date,
                    duration: duration,
                    location: location,
                    notes: notes,
                    rating: rating,
                    reachedOrgasm: reachedOrgasm,
                    dateAdded: Date()
                )
                
                // NEW: Use UUID-based create
                _ = try encounterService.create(
                    draft,
                    partnerIDs: partnerIDs,
                    activityTypeIDs: activityTypeIDs,
                    protectionMethodIDs: protectionMethodIDs
                )
                
                print("🔍 Create successful")
                
                // Update partner last encounter dates
                for partnerID in partnerIDs {
                    try? partnerService.updateLastEncounterDate(partnerID, date: date)
                }
            }
            
            print("🔍 Dismissing form")
            dismiss()
        } catch {
            print("❌ Save failed: \(error)")
            errorMessage = "Failed to save encounter. Please try again. Error: \(error.localizedDescription)"
        }
    }
}

#Preview("Add Encounter") {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }

    return EncounterFormView()
}
