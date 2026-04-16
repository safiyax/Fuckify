//
//  PositionsSelectionSection.swift
//  Fuckify
//
//  Position selection sections for encounter forms
//

import SwiftUI

// MARK: - My Position Section

struct MyPositionSection: View {
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?

    var body: some View {
        Section("My Position") {
            if availablePositions.isEmpty {
                Text("No position types available")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            } else if availablePositions.count <= 3 {
                Picker("Position", selection: $selectedPositionId) {
                    Text("None").tag(UUID?.none)
                    ForEach(availablePositions) { position in
                        Label(position.name, systemImage: position.icon)
                            .tag(Optional(position.id))
                    }
                }
                .pickerStyle(.segmented)
            } else {
                Picker("Position", selection: $selectedPositionId) {
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
}

// MARK: - Partner Positions Section

struct PartnerPositionsSection: View {
    let partners: [SQLPartner]
    let availablePositions: [SQLPositionType]
    @Binding var partnerPositionTypeIDs: [UUID: UUID?]

    var body: some View {
        if !partners.isEmpty && !availablePositions.isEmpty {
            Section("Partner Positions") {
                ForEach(partners) { partner in
                    PartnerPositionRow(
                        partner: partner,
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

// MARK: - Partner Position Row

private struct PartnerPositionRow: View {
    let partner: SQLPartner
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?

    var body: some View {
        HStack {
            // Partner avatar
            ZStack {
                Circle()
                    .fill(partner.color)
                    .frame(width: 32, height: 32)
                Text(partner.initials)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }

            Text(partner.name)
                .font(.body)

            Spacer()

            if availablePositions.count <= 3 {
                Picker("", selection: $selectedPositionId) {
                    Text("—").tag(UUID?.none)
                    ForEach(availablePositions) { position in
                        Text(position.name).tag(Optional(position.id))
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            } else {
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
}

#Preview {
    let positions = SQLPositionType.builtIns
    let partner = SQLPartner(id: UUID(), name: "Alex")

    Form {
        MyPositionSection(
            availablePositions: positions,
            selectedPositionId: .constant(SQLPositionType.topId)
        )
        PartnerPositionsSection(
            partners: [partner],
            availablePositions: positions,
            partnerPositionTypeIDs: .constant([:])
        )
    }
}
