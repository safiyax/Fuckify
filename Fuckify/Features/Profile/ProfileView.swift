//
//  ProfileView.swift
//  Fuckify
//

import SwiftUI

struct ProfileView: View {
    @Environment(UserProfile.self) private var profile
    @Environment(STIManager.self) private var stiManager
    @State private var showingSettings = false
    @State private var showingSTIForm = false
    @State private var isEditing = false

    // Editable fields
    @State private var editName: String = ""
    @State private var editDateOfBirth: Date?
    @State private var editShowDateOfBirth: Bool = false
    @State private var editNotes: String = ""
    @State private var editDefaultPositionTypeId: UUID? = nil
    @State private var availablePositions: [SQLPositionType] = []

    private var hasProfileData: Bool {
        !profile.name.isEmpty || profile.dateOfBirth != nil || !profile.notes.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                // Avatar Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color("AccentColor"))
                                    .frame(width: 100, height: 100)
                                Text(isEditing ? editName.initials : profile.initials)
                                    .font(.system(.largeTitle, weight: .bold))
                                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                                    .foregroundColor(.white)
                            }
                            if !isEditing {
                                Text(profile.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                if let age = profile.age {
                                    Text("\(age) years old")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // Basic Information (edit mode only)
                if isEditing {
                    Section("Basic Information") {
                        TextField("Name", text: $editName)
                            .textContentType(.name)
                        Toggle("Date of Birth", isOn: $editShowDateOfBirth)
                        if editShowDateOfBirth {
                            DatePicker(
                                "Date",
                                selection: Binding(
                                    get: { editDateOfBirth ?? Date() },
                                    set: { editDateOfBirth = $0 }
                                ),
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                        if !availablePositions.isEmpty {
                            Picker("Default Position", selection: $editDefaultPositionTypeId) {
                                Text("None").tag(UUID?.none)
                                ForEach(availablePositions) { position in
                                    Label(position.name, systemImage: position.icon)
                                        .tag(Optional(position.id))
                                }
                            }
                        }
                    }
                } else if !profile.name.isEmpty || profile.dateOfBirth != nil || profile.defaultPositionTypeId != nil {
                    Section("Basic Information") {
                        if let posId = profile.defaultPositionTypeId,
                           let position = availablePositions.first(where: { $0.id == posId }) {
                            HStack {
                                Text("Default Position")
                                Spacer()
                                Label(position.name, systemImage: position.icon)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // STI Testing Card
                Section("Sexual Health") {
                    STITestingCard(showingAddForm: $showingSTIForm)
                }

                // Notes Section
                Section("Notes") {
                    if isEditing {
                        TextEditor(text: $editNotes)
                            .frame(minHeight: 100)
                    } else if !profile.notes.isEmpty {
                        Text(profile.notes)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No notes")
                            .foregroundColor(.secondary)
                    }
                }

                // Last Updated
                if !isEditing && hasProfileData {
                    Section {
                        HStack {
                            Spacer()
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Text("Last updated: \(profile.lastModified.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .animation(nil, value: isEditing)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !isEditing {
                        Button {
                            withAnimation { isEditing = true }
                        } label: {
                            Text("Edit")
                        }
                    } else {
                        if #available(iOS 26.0, *) {
                            Button {
                                withAnimation { isEditing = false }
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .buttonStyle(.glassProminent)
                        } else {
                            Button {
                                withAnimation { isEditing = false }
                            } label: {
                                Text("Done")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !isEditing {
                        Button { showingSettings = true } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        .animation(nil, value: isEditing)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().dismissOnAppLock()
            }
            .sheet(isPresented: $showingSTIForm) {
                STITestFormView().dismissOnAppLock()
            }
            .onAppear {
                loadEditableFields()
                availablePositions = (try? PositionTypeService().fetchAll()) ?? []
            }
            .onChange(of: isEditing) { oldValue, newValue in
                if oldValue == true && newValue == false {
                    saveChanges()
                } else if oldValue == false && newValue == true {
                    loadEditableFields()
                }
            }
        }
    }

    private func loadEditableFields() {
        editName = profile.name
        editDateOfBirth = profile.dateOfBirth
        editShowDateOfBirth = profile.dateOfBirth != nil
        editNotes = profile.notes
        editDefaultPositionTypeId = profile.defaultPositionTypeId
    }

    private func saveChanges() {
        profile.name = editName
        profile.dateOfBirth = editShowDateOfBirth ? editDateOfBirth : nil
        profile.notes = editNotes
        profile.defaultPositionTypeId = editDefaultPositionTypeId
    }
}

// MARK: - STI Testing Card

private struct STITestingCard: View {
    @Environment(STIManager.self) private var stiManager
    @Binding var showingAddForm: Bool

    var body: some View {
        if stiManager.tests.isEmpty {
            // Empty state
            VStack(spacing: 12) {
                Image(systemName: "cross.case")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue.opacity(0.5))
                Text("Track Your STI Tests")
                    .font(.headline)
                Text("Log your test dates and results to stay on top of your sexual health.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showingAddForm = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Log First Test")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.bordered)
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        } else {
            // Summary card with navigation link to history
            NavigationLink(destination: STIHistoryView()) {
                VStack(alignment: .leading, spacing: 12) {
                    STISummaryRows(
                        manager: stiManager,
                        lastTestTitle: "Last STI Test",
                        colorEntireLastTestRow: true
                    )
                }
                .padding(.vertical, 8)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(UserProfile())
        .environment(STIManager())
}
