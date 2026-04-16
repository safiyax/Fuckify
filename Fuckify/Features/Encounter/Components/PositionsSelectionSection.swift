//
//  PositionsSelectionSection.swift
//  Fuckify
//
//  Combined position selection section — "Me" row first, then each partner.
//

import SwiftUI

// MARK: - Combined Positions Section

struct PositionsSection: View {
    let profile: UserProfile
    let partners: [SQLPartner]
    let availablePositions: [SQLPositionType]
    @Binding var myPositionTypeId: UUID?
    @Binding var partnerPositionTypeIDs: [UUID: UUID?]

    var body: some View {
        if !availablePositions.isEmpty {
            Section("Positions") {
                // Me row — always first
                EncounterPositionRow(
                    avatarColor: Color("AccentColor"),
                    initials: profile.initials,
                    name: profile.name.isEmpty ? "Me" : profile.name,
                    availablePositions: availablePositions,
                    selectedPositionId: $myPositionTypeId
                )

                // Partner rows
                ForEach(partners) { partner in
                    EncounterPositionRow(
                        avatarColor: partner.color,
                        initials: partner.initials,
                        name: partner.name,
                        availablePositions: availablePositions,
                        selectedPositionId: Binding(
                            get: { partnerPositionTypeIDs[partner.id] ?? nil },
                            set: { partnerPositionTypeIDs[partner.id] = $0 }
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Position Row

private struct EncounterPositionRow: View {
    let avatarColor: Color
    let initials: String
    let name: String
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?

    private var selectedName: String {
        guard let id = selectedPositionId,
              let position = availablePositions.first(where: { $0.id == id })
        else { return "None" }
        return position.name
    }

    var body: some View {
        HStack {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 32, height: 32)
                Text(initials)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            Text(name)
                .font(.body)

            Spacer()

            Picker("", selection: $selectedPositionId) {
                Text("None").tag(UUID?.none)
                ForEach(availablePositions) { position in
                    Label(position.name, systemImage: position.icon)
                        .tag(Optional(position.id))
                }
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    let positions = SQLPositionType.builtIns
    let partner = SQLPartner(id: UUID(), name: "Alex")
    let profile = UserProfile()

    return Form {
        PositionsSection(
            profile: profile,
            partners: [partner],
            availablePositions: positions,
            myPositionTypeId: .constant(SQLPositionType.topId),
            partnerPositionTypeIDs: .constant([:])
        )
    }
}
