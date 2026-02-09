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

                        Picker(selection: $durationMinutes, label: EmptyView()) {
                            ForEach([0, 15, 30, 45], id: \.self) { minute in
                                Text("\(minute)m").tag(minute)
                            }
                        }
                        .pickerStyle(.menu)
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
                    }
                }

                // Activities (NEW: database-backed)
                Section("Activities") {
                    ForEach(availableActivities.filter { $0.isEnabled }) { activity in
                        Button(action: { toggleActivity(activity.id) }) {
                            HStack {
                                Image(systemName: activity.icon)
                                    .foregroundColor(.purple)
                                    .accessibilityHidden(true)
                                Text(activity.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedActivityIDs.contains(activity.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(selectedActivityIDs.contains(activity.id) ? .isSelected : [])
                    }
                }

                // Protection (NEW: database-backed)
                Section("Protection") {
                    ForEach(availableProtectionMethods.filter { $0.isEnabled }) { protection in
                        Button(action: { toggleProtection(protection.id) }) {
                            HStack {
                                Image(systemName: protection.icon)
                                    .foregroundColor(.green)
                                    .accessibilityHidden(true)
                                Text(protection.name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedProtectionIDs.contains(protection.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                        .accessibilityHidden(true)
                                }
                            }
                        }
                        .accessibilityAddTraits(selectedProtectionIDs.contains(protection.id) ? .isSelected : [])
                    }
                }

                // Experience
                Section("Experience") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Rating")
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { star in
                                Button(action: { rating = star }) {
                                    Image(systemName: star <= rating ? "star.fill" : "star")
                                        .foregroundColor(star <= rating ? .yellow : .gray)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                                .accessibilityAddTraits(rating == star ? [.isSelected] : [])
                                .accessibilityHint("Double tap to rate this encounter")
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Reached Orgasm", isOn: $reachedOrgasm)
                        .accessibilityHint("Track whether you reached orgasm during this encounter")
                }

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

    private func toggleActivity(_ activityID: UUID) {
        if selectedActivityIDs.contains(activityID) {
            selectedActivityIDs.remove(activityID)
        } else {
            selectedActivityIDs.insert(activityID)
        }
    }

    private func toggleProtection(_ protectionID: UUID) {
        if selectedProtectionIDs.contains(protectionID) {
            selectedProtectionIDs.remove(protectionID)
        } else {
            selectedProtectionIDs.insert(protectionID)
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

// MARK: - Partner Chip Component

struct PartnerChip: View {
    let partner: SQLPartner
    let onRemove: () -> Void
    
    var partnerColor: Color {
        Color.fromPartnerColorName(partner.avatarColor)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(partner.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(partnerColor)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(partnerColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            partnerColor
                .opacity(0.15)
        )
        .cornerRadius(16)
    }
}

// MARK: - Chip Container

struct ChipContainer<Content: View>: View {
    @ViewBuilder let content: Content
    
    var body: some View {
        FlowLayout(spacing: 8) {
            content
        }
        .padding(4)
    }
}

// MARK: - Partner Picker Sheet

struct PartnerPickerSheet: View {
    let allPartners: [SQLPartner]
    @Binding var selectedPartnerIDs: Set<UUID>
    @Binding var searchText: String
    @Environment(\.dismiss) private var dismiss
    
    var filteredPartners: [SQLPartner] {
        let partners: [SQLPartner]
        if searchText.isEmpty {
            partners = allPartners
        } else {
            partners = allPartners.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Sort: pinned first, then by name
        return partners.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned // Pinned partners come first
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    var pinnedPartners: [SQLPartner] {
        filteredPartners.filter { $0.isPinned }
    }
    
    var unpinnedPartners: [SQLPartner] {
        filteredPartners.filter { !$0.isPinned }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if allPartners.isEmpty {
                    ContentUnavailableView(
                        "No Partners",
                        systemImage: "person.2.slash",
                        description: Text("Add partners first to log encounters with them")
                    )
                } else {
                    // Pinned Partners Section
                    if !pinnedPartners.isEmpty {
                        Section("Pinned") {
                            ForEach(pinnedPartners) { partner in
                                PartnerPickerRow(
                                    partner: partner,
                                    isSelected: selectedPartnerIDs.contains(partner.id),
                                    onTap: { togglePartner(partner.id) }
                                )
                            }
                        }
                    }
                    
                    // All Partners Section
                    if !unpinnedPartners.isEmpty {
                        Section(pinnedPartners.isEmpty ? "" : "All Partners") {
                            ForEach(unpinnedPartners) { partner in
                                PartnerPickerRow(
                                    partner: partner,
                                    isSelected: selectedPartnerIDs.contains(partner.id),
                                    onTap: { togglePartner(partner.id) }
                                )
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search partners")
            .navigationTitle("Select Partners")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
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
}

// MARK: - Partner Picker Row

struct PartnerPickerRow: View {
    let partner: SQLPartner
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color avatar
                Circle()
                    .fill(Color.fromPartnerColorName(partner.avatarColor))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Text(partner.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(partner.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if partner.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if !partner.notes.isEmpty {
                        Text(partner.notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview("Add Encounter") {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }

    return EncounterFormView()
}
