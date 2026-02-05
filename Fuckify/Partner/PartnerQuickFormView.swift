//
//  PartnerQuickFormView.swift
//  Fuckify
//
//  Quick partner creation for Live Activity flow
//

import SwiftUI
import Dependencies

struct PartnerQuickFormView: View {
    @Dependency(\.partnerService) var partnerService
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var avatarColor: String = SQLPartner.randomColorName()
    @State private var relationshipType: SQLRelationshipType = .casual
    @State private var errorMessage: String?
    @State private var isSaving = false
    
    var onSave: ((SQLPartner) -> Void)?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                }
                
                Section("Appearance") {
                    ColorPickerRow(selectedColor: $avatarColor)
                }
                
                Section("Relationship") {
                    Picker("Type", selection: $relationshipType) {
                        ForEach([SQLRelationshipType.casual, .regular, .committed, .oneTime, .other], id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Partner")
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
                            await savePartner()
                        }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
        }
    }
    
    @MainActor
    private func savePartner() async {
        errorMessage = nil
        isSaving = true
        
        defer { isSaving = false }
        
        let draft = SQLPartner.Draft(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: "",
            phoneNumber: "",
            isOnPrep: false,
            relationshipType: relationshipType,
            dateMet: nil,
            avatarColor: avatarColor,
            dateAdded: Date(),
            lastEncounterDate: nil,
            isPinned: false
        )
        
        do {
            let partner = try partnerService.create(draft)
            onSave?(partner)
            dismiss()
        } catch {
            errorMessage = "Failed to create partner. Please try again."
        }
    }
}

// MARK: - Color Picker Row

struct ColorPickerRow: View {
    @Binding var selectedColor: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(PartnerColors.allColorNames, id: \.self) { colorName in
                        ColorCircle(
                            colorName: colorName,
                            isSelected: selectedColor == colorName,
                            onTap: { selectedColor = colorName }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ColorCircle: View {
    let colorName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(Color.fromPartnerColorName(colorName))
                    .frame(width: 44, height: 44)
                
                if isSelected {
                    Circle()
                        .stroke(Color.primary, lineWidth: 3)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PartnerQuickFormView()
}
