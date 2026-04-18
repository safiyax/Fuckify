//
//  DeleteDataView.swift
//  Fuckify
//
//

import SwiftUI
import Dependencies
import UserNotifications

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "DeleteData")

struct DeleteDataView: View {
    @Dependency(\.partnerService) private var partnerService
    @Dependency(\.encounterService) private var encounterService
    @Environment(\.dismiss) private var dismiss
    @Environment(UserProfile.self) private var userProfile
    
    @State private var allPartners: [SQLPartner] = []
    @State private var allEncounters: [SQLEncounter] = []

    @State private var showingDeletePartnersAlert = false
    @State private var showingDeleteEncountersAlert = false
    @State private var showingDeleteProfileAlert = false
    @State private var showingDeleteAllAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Warning: These actions cannot be undone. Your data will be permanently deleted.")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }

                Section("Delete Specific Data") {
                    Button(action: { showingDeletePartnersAlert = true }) {
                        HStack {
                            SettingsRow(icon: "person.2.fill", color: .red, label: "Delete All Partners")
                            Spacer()
                            Text("\(allPartners.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(allPartners.isEmpty)

                    Button(action: { showingDeleteEncountersAlert = true }) {
                        HStack {
                            SettingsRow(icon: "heart.fill", color: .red, label: "Delete All Encounters")
                            Spacer()
                            Text("\(allEncounters.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(allEncounters.isEmpty)

                    Button(action: { showingDeleteProfileAlert = true }) {
                        SettingsRow(icon: "person.crop.circle.fill", color: .red, label: "Delete Profile Data")
                    }
                    .disabled(!userProfile.hasProfile)
                }

                Section("Delete Everything") {
                    Button(action: { showingDeleteAllAlert = true }) {
                        SettingsRow(icon: "trash.fill", color: .red, label: "Delete All Data")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                    .disabled(allPartners.isEmpty && allEncounters.isEmpty && !userProfile.hasProfile)
                }
            }
            .navigationTitle("Delete Data")
            .navigationBarTitleDisplayMode(.inline)
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                }
//            }
            .alert("Delete All Partners?", isPresented: $showingDeletePartnersAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllPartners()
                }
            } message: {
                Text("This will permanently delete all \(allPartners.count) partner(s). This action cannot be undone.")
            }
            .alert("Delete All Encounters?", isPresented: $showingDeleteEncountersAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteAllEncounters()
                }
            } message: {
                Text("This will permanently delete all \(allEncounters.count) encounter(s). This action cannot be undone.")
            }
            .alert("Delete Profile Data?", isPresented: $showingDeleteProfileAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteProfileData()
                }
            } message: {
                Text("This will permanently delete your profile information. This action cannot be undone.")
            }
            .alert("Delete All Data?", isPresented: $showingDeleteAllAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete ALL your data including partners, encounters, and profile. This action cannot be undone.")
            }
            .task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        if let partners = try? partnerService.fetchAll() {
            allPartners = partners
        }
        if let encounters = try? encounterService.fetchAll() {
            allEncounters = encounters
        }
    }

    private func deleteAllPartners() {
        logger.info("Deleting all partners (\(allPartners.count))")
        for partner in allPartners {
            do {
                try partnerService.delete(partner.id)
            } catch {
                logger.error("Failed to delete partner \(partner.id): \(error.localizedDescription)")
            }
        }
        allPartners = []
    }

    private func deleteAllEncounters() {
        logger.info("Deleting all encounters (\(allEncounters.count))")
        for encounter in allEncounters {
            do {
                try encounterService.delete(encounter.id)
            } catch {
                logger.error("Failed to delete encounter \(encounter.id): \(error.localizedDescription)")
            }
        }
        allEncounters = []
    }

    private func deleteProfileData() {
        logger.info("Deleting profile data")
        userProfile.clearProfile()
    }

    private func deleteAllSTITests() {
        logger.info("Deleting all STI tests")
        do {
            try STIService().deleteAll()
        } catch {
            logger.error("Failed to delete STI tests: \(error.localizedDescription)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["sti-test-reminder"])
    }

    private func deleteAllData() {
        logger.info("Deleting all data")
        deleteAllPartners()
        deleteAllEncounters()
        deleteAllSTITests()
        deleteProfileData()
    }
}

#Preview {
    DeleteDataView()
}
