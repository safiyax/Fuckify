//
//  DeleteDataView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct DeleteDataView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPartners: [Partner]
    @Query private var allEncounters: [Encounter]

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
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.red)
                            Text("Delete All Partners")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(allPartners.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(allPartners.isEmpty)

                    Button(action: { showingDeleteEncountersAlert = true }) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("Delete All Encounters")
                                .foregroundColor(.primary)
                            Spacer()
                            Text("\(allEncounters.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(allEncounters.isEmpty)

                    Button(action: { showingDeleteProfileAlert = true }) {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.red)
                            Text("Delete Profile Data")
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(!UserProfile.shared.hasProfile)
                }

                Section("Delete Everything") {
                    Button(action: { showingDeleteAllAlert = true }) {
                        HStack {
                            Image(systemName: "trash.fill")
                                .foregroundColor(.red)
                            Text("Delete All Data")
                                .foregroundColor(.red)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(allPartners.isEmpty && allEncounters.isEmpty && !UserProfile.shared.hasProfile)
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
        }
    }

    private func deleteAllPartners() {
        for partner in allPartners {
            modelContext.delete(partner)
        }
    }

    private func deleteAllEncounters() {
        for encounter in allEncounters {
            modelContext.delete(encounter)
        }
    }

    private func deleteProfileData() {
        UserProfile.shared.clearProfile()
    }

    private func deleteAllData() {
        deleteAllPartners()
        deleteAllEncounters()
        deleteProfileData()
    }
}

#Preview {
    DeleteDataView()
        .modelContainer(for: [Partner.self, Encounter.self], inMemory: true)
}
