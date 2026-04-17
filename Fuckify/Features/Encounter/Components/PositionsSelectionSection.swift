//
//  PositionsSelectionSection.swift
//  Fuckify
//
//  Accordion-style participant section for encounter forms.
//  Each participant (Me + partners) can expand to reveal position and orgasm fields.
//

import SwiftUI

// MARK: - Participants Section

struct ParticipantsSection: View {
    let profile: UserProfile
    let partners: [SQLPartner]
    let availablePositions: [SQLPositionType]

    @Binding var myPositionTypeId: UUID?
    @Binding var myReachedOrgasm: Bool
    @Binding var partnerPositionTypeIDs: [UUID: UUID?]
    @Binding var partnerOrgasms: [UUID: Bool]

    // Sentinel UUID used to track expanded state for the "Me" row
    private let meID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    @State private var expandedIDs: Set<UUID> = []

    var body: some View {
        Section("Participants") {
            // Me — header row
            ParticipantHeaderRow(
                avatarColor: Color("AccentColor"),
                initials: profile.initials,
                name: profile.name.isEmpty ? "Me" : profile.name,
                isExpanded: expandedIDs.contains(meID),
                onToggleExpand: { toggleExpand(meID) }
            )
            // Me — expanded detail row
            if expandedIDs.contains(meID) {
                ParticipantDetailRow(
                    availablePositions: availablePositions,
                    selectedPositionId: $myPositionTypeId,
                    hadOrgasm: $myReachedOrgasm
                )
                .transition(.opacity)
            }

            // Partners
            ForEach(partners) { partner in
                ParticipantHeaderRow(
                    avatarColor: partner.color,
                    initials: partner.initials,
                    name: partner.name,
                    isExpanded: expandedIDs.contains(partner.id),
                    onToggleExpand: { toggleExpand(partner.id) }
                )
                if expandedIDs.contains(partner.id) {
                    ParticipantDetailRow(
                        availablePositions: availablePositions,
                        selectedPositionId: Binding(
                            get: { partnerPositionTypeIDs[partner.id] ?? nil },
                            set: { partnerPositionTypeIDs[partner.id] = $0 }
                        ),
                        hadOrgasm: Binding(
                            get: { partnerOrgasms[partner.id] ?? false },
                            set: { partnerOrgasms[partner.id] = $0 }
                        )
                    )
                    .transition(.opacity)
                }
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
            } else {
                expandedIDs.insert(id)
            }
        }
    }
}

// MARK: - Participant Header Row

private struct ParticipantHeaderRow: View {
    let avatarColor: Color
    let initials: String
    let name: String
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        Button(action: onToggleExpand) {
            HStack {
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
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Participant Detail Row (separate List row when expanded)

private struct ParticipantDetailRow: View {
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?
    @Binding var hadOrgasm: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Position picker
            if !availablePositions.isEmpty {
                HStack {
                    Label("Position", systemImage: "figure.stand")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer()
                    Picker("", selection: $selectedPositionId) {
                        Label("None", systemImage: "minus.circle")
                            .tag(UUID?.none)
                        ForEach(availablePositions) { position in
                            Label(position.name, systemImage: position.icon)
                                .tag(Optional(position.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Orgasm toggle
            Toggle(isOn: $hadOrgasm) {
                Label("Orgasm", systemImage: hadOrgasm ? "heart.fill" : "heart")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(.leading, 48)
    }
}

// MARK: - Preview

#Preview {
    let positions = SQLPositionType.builtIns
    let partner = SQLPartner(id: UUID(), name: "Alex")
    let profile = UserProfile()

    Form {
        ParticipantsSection(
            profile: profile,
            partners: [partner],
            availablePositions: positions,
            myPositionTypeId: .constant(SQLPositionType.topId),
            myReachedOrgasm: .constant(false),
            partnerPositionTypeIDs: .constant([:]),
            partnerOrgasms: .constant([:])
        )
    }
}
