//
//  ProfileView.swift
//  Fuckify
//
//

import SwiftUI

struct ProfileView: View {
    @Environment(UserProfile.self) private var profile
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
    
    // MARK: - Computed Properties
    
    private var hasHealthInfo: Bool {
        profile.isOnPrep || profile.lastSTITestDate != nil
    }
    
    private var stiTestStatus: (text: String, color: Color, icon: String) {
        guard let lastTest = profile.lastSTITestDate else {
            return ("Never tested", .red, "exclamationmark.triangle.fill")
        }
        
        let days = Calendar.current.dateComponents([.day], from: lastTest, to: Date()).day ?? 0
        
        // Use 90-day threshold (CDC recommendation for regular testing)
        if days < 90 {
            return ("\(days) days ago", .green, "checkmark.circle.fill")
        } else if days < 180 {
            return ("\(days) days ago", .orange, "exclamationmark.circle.fill")
        } else {
            return ("\(days) days ago", .red, "exclamationmark.triangle.fill")
        }
    }
    
    private var hasProfileData: Bool {
        !profile.name.isEmpty || profile.dateOfBirth != nil || hasHealthInfo || !profile.notes.isEmpty
    }
    
    private func calculateNextTestDate() -> Date? {
        guard let lastTest = profile.lastSTITestDate else { return nil }
        
        // Recommend testing every 3 months (90 days) - CDC recommendation
        let interval = 90
        
        let nextDate = Calendar.current.date(byAdding: .day, value: interval, to: lastTest)
        
        // Only return if the date is in the future
        if let next = nextDate, next > Date() {
            return next
        }
        
        return nil
    }
    
    private var daysUntilNextTest: Int? {
        guard let nextTest = calculateNextTestDate() else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: nextTest).day
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
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    }
                }
                
                // Health Check-In Section
                Section(isEditing ? "Health" : "Health Check-In") {
                    if isEditing {
                        // Edit mode - toggles and date pickers
                        Toggle("On PrEP", isOn: $editIsOnPrep)
                        
                        Toggle("Last STI Test", isOn: $editShowLastSTITestDate)
                        
                        if editShowLastSTITestDate {
                            DatePicker(
                                "Date",
                                selection: Binding(
                                    get: { editLastSTITestDate ?? Date() },
                                    set: { editLastSTITestDate = $0 }
                                ),
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                        }
                    } else {
                        // View mode
                        if hasHealthInfo {
                            VStack(spacing: 12) {
                                // Last STI Test
                                HStack {
                                    Label("Last STI Test", systemImage: "calendar.badge.clock")
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: stiTestStatus.icon)
                                        Text(stiTestStatus.text)
                                            .fontWeight(.medium)
                                    }
                                    .foregroundColor(stiTestStatus.color)
                                }
                                
                                // Next Test Due (if applicable)
                                if let nextTestDate = calculateNextTestDate(), let daysUntil = daysUntilNextTest {
                                    Divider()
                                    
                                    HStack {
                                        Label("Next Test Due", systemImage: "bell.badge")
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(nextTestDate.formatted(date: .abbreviated, time: .omitted))
                                                .fontWeight(.medium)
                                            Text("in \(daysUntil) days")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        .foregroundColor(.orange)
                                    }
                                }
                                
                                Divider()
                                
                                // PrEP Status
                                HStack {
                                    Label("PrEP Status", systemImage: "pills.fill")
                                    Spacer()
                                    if profile.isOnPrep {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                            Text("Active")
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.blue)
                                    } else {
                                        Text("Not Active")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 8)
                        } else {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "pills.circle")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue.opacity(0.5))
                                
                                Text("Track Your Sexual Wellness")
                                    .font(.headline)
                                
                                Text("Add your PrEP status and STI testing dates to stay on top of your sexual health")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button(action: {
                                    withAnimation {
                                        isEditing = true
                                    }
                                }) {
                                    Label("Add Health Info", systemImage: "plus.circle.fill")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
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
                
                // Last Updated Section
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
                            Button(action: {
                                withAnimation {
                                    isEditing.toggle()
                                }
                            }) {
                                Text("Edit")
                            }
                            .disabled(isEditing && editName.trimmingCharacters(in: .whitespaces).isEmpty)
                        } else {
                            if #available(iOS 26.0, *) {
                                Button(action: {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                }) {
                                    Label("Save", systemImage: "checkmark")
                                }
                                .buttonStyle(.glassProminent)
                            } else {
                                Button(action: {
                                    withAnimation {
                                        isEditing.toggle()
                                    }
                                }) {
                                    Text("Done")
                                }
                            }
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
                        .dismissOnAppLock()
                }
                .onAppear {
                    loadEditableFields()
                }
                .onChange(of: isEditing) { oldValue, newValue in
                    if oldValue == true && newValue == false {
                        // Save changes when exiting edit mode
                        saveChanges()
                    } else if oldValue == false && newValue == true {
                        // Reload fields when entering edit mode
                        loadEditableFields()
                    }
                }
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
