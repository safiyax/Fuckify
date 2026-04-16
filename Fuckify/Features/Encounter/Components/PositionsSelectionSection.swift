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
            // Me row — always first
            ParticipantRow(
                id: meID,
                avatarColor: Color("AccentColor"),
                initials: profile.initials,
                name: profile.name.isEmpty ? "Me" : profile.name,
                availablePositions: availablePositions,
                selectedPositionId: $myPositionTypeId,
                hadOrgasm: $myReachedOrgasm,
                isExpanded: expandedIDs.contains(meID),
                onToggleExpand: { toggleExpand(meID) }
            )

            // Partner rows
            ForEach(partners) { partner in
                ParticipantRow(
                    id: partner.id,
                    avatarColor: partner.color,
                    initials: partner.initials,
                    name: partner.name,
                    availablePositions: availablePositions,
                    selectedPositionId: Binding(
                        get: { partnerPositionTypeIDs[partner.id] ?? nil },
                        set: { partnerPositionTypeIDs[partner.id] = $0 }
                    ),
                    hadOrgasm: Binding(
                        get: { partnerOrgasms[partner.id] ?? false },
                        set: { partnerOrgasms[partner.id] = $0 }
                    ),
                    isExpanded: expandedIDs.contains(partner.id),
                    onToggleExpand: { toggleExpand(partner.id) }
                )
            }
        }
    }

    private func toggleExpand(_ id: UUID) {
        if expandedIDs.contains(id) {
            expandedIDs.remove(id)
        } else {
            expandedIDs.insert(id)
        }
    }
}

// MARK: - Participant Row

private struct ParticipantRow: View {
    let id: UUID
    let avatarColor: Color
    let initials: String
    let name: String
    let availablePositions: [SQLPositionType]
    @Binding var selectedPositionId: UUID?
    @Binding var hadOrgasm: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible, tap to expand/collapse
            Button(action: onToggleExpand) {
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
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.vertical, 8)

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
                        .padding(.bottom, 8)
                    }

                    // Orgasm toggle
                    Toggle(isOn: $hadOrgasm) {
                        Label("Orgasm", systemImage: hadOrgasm ? "heart.fill" : "heart")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }
                .padding(.leading, 48)  // indent to align with name
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .padding(.vertical, 4)
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
