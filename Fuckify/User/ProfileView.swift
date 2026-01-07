//
//  ProfileView.swift
//  Fuckify
//
//

import SwiftUI

struct ProfileView: View {
    @State private var profile = UserProfile.shared
    @State private var hasProfile = UserProfile.shared.hasProfile
    @State private var showingSettings = false
//    @Environment(\.editMode) private var editMode

    // Editable fields
    @State private var editName: String = ""
    @State private var editDateOfBirth: Date?
    @State private var editShowDateOfBirth: Bool = false
    @State private var editIsOnPrep: Bool = false
    @State private var editLastSTITestDate: Date?
    @State private var editShowLastSTITestDate: Bool = false
    @State private var editNotes: String = ""


    @State private var isEditing = false
    @State private var viewId = UUID()

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
                                    .font(.system(size: 40, weight: .bold))
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

                // Basic Information
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
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    }
                }

                // Health Section
                Section("Health") {
                    if isEditing {
                        Toggle("On PrEP", isOn: $editIsOnPrep)

                        Toggle("Last STI Test", isOn: $editShowLastSTITestDate)

                        if editShowLastSTITestDate {
                            DatePicker(
                                "Date",
                                selection: Binding(
                                    get: { editLastSTITestDate ?? Date() },
                                    set: { editLastSTITestDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    } else {
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
            }
                .navigationBarTitleDisplayMode(.inline)
                .animation(nil, value: isEditing)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        if !isEditing {
                            Button(action: {
                                withAnimation {
                                    isEditing.toggle()
                                }
                            }) {
                                Text("Edit")
                            }
                            .disabled(isEditing && editName.trimmingCharacters(in: .whitespaces).isEmpty)
                        } else {
                            Button(action: {
                                withAnimation {
                                    isEditing.toggle()
                                }
                            }) {
                                Label("Save", systemImage: "checkmark")
                            }
                            .buttonStyle(.glassProminent)
                        }
                    }

                    ToolbarItem(placement: .topBarLeading) {
                        if !isEditing {
                            Button(action: { showingSettings = true }) {
                                Label("Settings", systemImage: "gear")
                            }
                            .animation(nil, value: isEditing)
                        }
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    SettingsView()
                }
                .onAppear {
                    loadEditableFields()
                }
                .onChange(of: isEditing) { oldValue, newValue in
                    if oldValue == true && newValue == false {
                        // Save changes when exiting edit mode
                        print("save")
                        saveChanges()
                        viewId = UUID()
                    } else if oldValue == false && newValue == true {
                        // Reload fields when entering edit mode
                        print("load editable")
                        loadEditableFields()
                        viewId = UUID()
                    }
                }
                .id(viewId)
        }
    }


    // MARK: - Functions

    private func loadEditableFields() {
        editName = profile.name
        editDateOfBirth = profile.dateOfBirth
        editShowDateOfBirth = profile.dateOfBirth != nil
        editIsOnPrep = profile.isOnPrep
        editLastSTITestDate = profile.lastSTITestDate
        editShowLastSTITestDate = profile.lastSTITestDate != nil
        editNotes = profile.notes
    }

    private func saveChanges() {
        profile.name = editName
        profile.dateOfBirth = editShowDateOfBirth ? editDateOfBirth : nil
        profile.isOnPrep = editIsOnPrep
        profile.lastSTITestDate = editShowLastSTITestDate ? editLastSTITestDate : nil
        profile.notes = editNotes
    }
}

#Preview {
    ProfileView()
}
