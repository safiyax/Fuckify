//
//  PartnerPickerSheet.swift
//  Fuckify
//
//  Sheet for selecting multiple partners
//

import SwiftUI
import SQLiteData

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

#Preview {
    PartnerPickerSheet(
        allPartners: [],
        selectedPartnerIDs: .constant([]),
        searchText: .constant("")
    )
}
