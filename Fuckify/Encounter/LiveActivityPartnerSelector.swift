//
//  LiveActivityPartnerSelector.swift
//  Fuckify
//
//  Partner selection sheet for starting Live Activity
//

import SwiftUI
import SQLiteData
import Dependencies

struct LiveActivityPartnerSelector: View {
    @Environment(\.dismiss) private var dismiss
    @FetchAll(SQLPartner.order(by: \.name))
    private var allPartners: [SQLPartner]
    
    @State private var selectedPartnerIDs: Set<UUID> = []
    @State private var showingPartnerPicker = false
    @State private var showingNewPartnerForm = false
    @State private var partnerSearchText = ""
    @Environment(LiveActivityManager.self) private var liveActivityManager
    
    var selectedPartners: [SQLPartner] {
        allPartners.filter { selectedPartnerIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                    
                    Text("Start Live Tracking")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select partners for this encounter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Selected partners
                if selectedPartners.isEmpty {
                    ContentUnavailableView(
                        "No Partners Selected",
                        systemImage: "person.2.slash",
                        description: Text("Add partners to start tracking")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("With:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(selectedPartners) { partner in
                                PartnerChip(
                                    partner: partner,
                                    onRemove: { togglePartner(partner.id) }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    // Start tracking button
                    Button {
                        Task {
                            await startTracking()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "timer")
                            Text("Start Tracking")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedPartners.isEmpty)
                    
                    // Add partner button
                    Button {
                        showingPartnerPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "person.badge.plus")
                            Text("Select Partners")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(12)
                    }
                    
                    // Create new partner button
                    Button {
                        showingNewPartnerForm = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create New Partner")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPartnerPicker) {
                PartnerPickerSheet(
                    allPartners: allPartners,
                    selectedPartnerIDs: $selectedPartnerIDs,
                    searchText: $partnerSearchText
                )
            }
            .sheet(isPresented: $showingNewPartnerForm) {
                PartnerQuickFormView { newPartner in
                    // Auto-select the newly created partner
                    selectedPartnerIDs.insert(newPartner.id)
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
    
    @MainActor
    private func startTracking() async {
        let partners = selectedPartners
        
        let success = await liveActivityManager.startEncounter(partners: partners)
        
        if success {
            dismiss()
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return LiveActivityPartnerSelector()
}
