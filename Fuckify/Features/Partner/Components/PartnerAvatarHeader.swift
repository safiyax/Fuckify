//
//  PartnerAvatarHeader.swift
//  Fuckify
//
//  Avatar header component for partner detail views
//

import SwiftUI
import SQLiteData

struct PartnerAvatarHeader: View {
    let partner: SQLPartner
    let isEditing: Bool
    let editName: String
    let editAvatarColor: String
    
    var displayColor: Color {
        isEditing ? Color.fromPartnerColorName(editAvatarColor) : partner.color
    }
    
    var displayInitials: String {
        isEditing ? editName.initials : partner.initials
    }
    
    var body: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(displayColor)
                            .frame(width: 100, height: 100)

                        Text(displayInitials)
                            .font(.system(.largeTitle, weight: .bold))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .foregroundColor(.white)
                    }
                    .accessibilityLabel("\(partner.name) avatar")
                    .accessibilityValue("Color: \(isEditing ? editAvatarColor : partner.avatarColor)")

                    if !isEditing {
                        Text(partner.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(partner.relationshipType.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }
}

#Preview {
    let partner = SQLPartner(
        id: UUID(),
        name: "John Doe",
        notes: "",
        phoneNumber: "",
        relationshipType: .regular,
        dateMet: nil,
        avatarColor: "blue",
        dateAdded: Date(),
        lastEncounterDate: nil,
        isPinned: false
    )
    
    List {
        PartnerAvatarHeader(
            partner: partner,
            isEditing: false,
            editName: "",
            editAvatarColor: ""
        )
    }
}
