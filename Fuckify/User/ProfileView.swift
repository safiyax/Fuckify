//
//  ProfileView.swift
//  Fuckify
//
//

import SwiftUI

struct ProfileView: View {
    @State private var profile = UserProfile.shared
    @State private var isEditing = false
    @State private var hasProfile = UserProfile.shared.hasProfile

    var body: some View {
        NavigationStack {
            if hasProfile && !isEditing {
                // Display Mode
                profileDisplayView
            } else {
                // Edit Mode
                profileEditViewInline
            }
        }
    }

    private var profileDisplayView: some View {
        List {
            // Avatar Section
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 100, height: 100)

                            Text(profile.initials)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text(profile.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        if let age = profile.age {
                            Text("\(age) years old")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)

            // Health Section
            Section("Health") {
                HStack {
                    Text("PrEP Status")
                    Spacer()
                    if profile.isOnPrep {
                        Label("On PrEP", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Text("Not on PrEP")
                            .foregroundColor(.secondary)
                    }
                }

                if let lastTest = profile.lastSTITestDate {
                    HStack {
                        Text("Last STI Test")
                        Spacer()
                        Text(lastTest.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Notes Section
            if !profile.notes.isEmpty {
                Section("Notes") {
                    Text(profile.notes)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
    }

    private var profileEditViewInline: some View {
        ProfileEditInlineView(isEditing: $isEditing, hasProfile: $hasProfile)
    }
}

// MARK: - Profile Edit Inline View (for tab navigation)

struct ProfileEditInlineView: View {
    @State private var profile = UserProfile.shared
    @Binding var isEditing: Bool
    @Binding var hasProfile: Bool

    @State private var name: String = ""
    @State private var dateOfBirth: Date?
    @State private var showDateOfBirth: Bool = false
    @State private var isOnPrep: Bool = false
    @State private var lastSTITestDate: Date?
    @State private var showLastSTITestDate: Bool = false
    @State private var notes: String = ""

    var body: some View {
        Form {
            Section("Basic Information") {
                TextField("Name", text: $name)
                    .textContentType(.name)

                Toggle("Date of Birth", isOn: $showDateOfBirth)

                if showDateOfBirth {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { dateOfBirth ?? Date() },
                            set: { dateOfBirth = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
            }

            Section("Health") {
                Toggle("On PrEP", isOn: $isOnPrep)

                Toggle("Last STI Test", isOn: $showLastSTITestDate)

                if showLastSTITestDate {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { lastSTITestDate ?? Date() },
                            set: { lastSTITestDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle(profile.hasProfile ? "Edit Profile" : "Create Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            loadProfile()
        }
    }

    private func loadProfile() {
        name = profile.name
        dateOfBirth = profile.dateOfBirth
        showDateOfBirth = profile.dateOfBirth != nil
        isOnPrep = profile.isOnPrep
        lastSTITestDate = profile.lastSTITestDate
        showLastSTITestDate = profile.lastSTITestDate != nil
        notes = profile.notes
    }

    private func saveProfile() {
        profile.name = name
        profile.dateOfBirth = showDateOfBirth ? dateOfBirth : nil
        profile.isOnPrep = isOnPrep
        profile.lastSTITestDate = showLastSTITestDate ? lastSTITestDate : nil
        profile.notes = notes

        // Update state to show display mode
        hasProfile = true
        isEditing = false
    }
}

// MARK: - Profile Edit View

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile = UserProfile.shared
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var dateOfBirth: Date?
    @State private var showDateOfBirth: Bool = false
    @State private var isOnPrep: Bool = false
    @State private var lastSTITestDate: Date?
    @State private var showLastSTITestDate: Bool = false
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                        .textContentType(.name)

                    Toggle("Date of Birth", isOn: $showDateOfBirth)

                    if showDateOfBirth {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { dateOfBirth ?? Date() },
                                set: { dateOfBirth = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }

                Section("Health") {
                    Toggle("On PrEP", isOn: $isOnPrep)

                    Toggle("Last STI Test", isOn: $showLastSTITestDate)

                    if showLastSTITestDate {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { lastSTITestDate ?? Date() },
                                set: { lastSTITestDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(profile.hasProfile ? "Edit Profile" : "Create Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if profile.hasProfile {
                            isPresented = false
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    private func loadProfile() {
        name = profile.name
        dateOfBirth = profile.dateOfBirth
        showDateOfBirth = profile.dateOfBirth != nil
        isOnPrep = profile.isOnPrep
        lastSTITestDate = profile.lastSTITestDate
        showLastSTITestDate = profile.lastSTITestDate != nil
        notes = profile.notes
    }

    private func saveProfile() {
        profile.name = name
        profile.dateOfBirth = showDateOfBirth ? dateOfBirth : nil
        profile.isOnPrep = isOnPrep
        profile.lastSTITestDate = showLastSTITestDate ? lastSTITestDate : nil
        profile.notes = notes

        if profile.hasProfile {
            isPresented = false
        } else {
            dismiss()
        }
    }
}

#Preview {
    ProfileView()
}
