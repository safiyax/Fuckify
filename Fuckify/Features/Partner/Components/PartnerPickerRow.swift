//
//  PartnerPickerRow.swift
//  Fuckify
//
//  Row component for partner picker lists
//

import SwiftUI
import SQLiteData

struct PartnerPickerRow: View {
    let partner: SQLPartner
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                PartnerAvatar(
                    color: Color.fromPartnerColorName(partner.avatarColor),
                    initials: partner.name.prefix(1).uppercased(),
                    size: 40
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(partner.name)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        if partner.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption2)
                                .foregroundColor(.orange)
                                .accessibilityLabel("Pinned")
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
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityLabel(partner.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to \(isSelected ? "deselect" : "select") this partner")
    }
}

#Preview {
    let partner = SQLPartner(
        id: UUID(),
        name: "John Doe",
        notes: "Met at the gym",
        phoneNumber: "",
        relationshipType: .casual,
        dateMet: nil,
        avatarColor: "blue",
        dateAdded: Date(),
        lastEncounterDate: nil,
        isPinned: true
    )
    
    List {
        PartnerPickerRow(partner: partner, isSelected: true, onTap: {})
        PartnerPickerRow(partner: partner, isSelected: false, onTap: {})
    }
}
