//
//  PartnerChip.swift
//  Fuckify
//
//  Reusable partner chip component for displaying selected partners
//

import SwiftUI
import SQLiteData

struct PartnerChip: View {
    let partner: SQLPartner
    let onRemove: () -> Void
    
    var partnerColor: Color {
        Color.fromPartnerColorName(partner.avatarColor)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(partner.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundColor(partnerColor)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(partnerColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(partner.name)")
            .accessibilityHint("Removes this partner from the encounter")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            partnerColor
                .opacity(0.15)
        )
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let partner = SQLPartner(
        id: UUID(),
        name: "John Doe",
        notes: "",
        phoneNumber: "",
        relationshipType: .casual,
        dateMet: nil,
        avatarColor: "blue",
        dateAdded: Date(),
        lastEncounterDate: nil,
        isPinned: false
    )
    
    PartnerChip(partner: partner, onRemove: {})
        .padding()
}
