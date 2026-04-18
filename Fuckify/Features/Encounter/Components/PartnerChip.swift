//
//  PartnerChip.swift
//  Fuckify
//
//  Reusable partner chip component for displaying selected partners
//

import SwiftUI
import SQLiteData

enum PartnerChipMode {
    case removable(onRemove: () -> Void)
    case detail(positionIcon: String?, hadOrgasm: Bool)
    case display
}

struct PartnerChip: View {
    let partner: SQLPartner
    let mode: PartnerChipMode

    init(partner: SQLPartner, mode: PartnerChipMode) {
        self.partner = partner
        self.mode = mode
    }

    init(partner: SQLPartner, onRemove: @escaping () -> Void) {
        self.partner = partner
        self.mode = .removable(onRemove: onRemove)
    }

    private var partnerColor: Color {
        Color.fromPartnerColorName(partner.avatarColor)
    }

    private var spacing: CGFloat {
        switch mode {
        case .display:
            8
        case .removable, .detail:
            6
        }
    }

    private var verticalPadding: CGFloat {
        switch mode {
        case .display:
            8
        case .removable, .detail:
            6
        }
    }

    private var cornerRadius: CGFloat {
        switch mode {
        case .display:
            20
        case .removable, .detail:
            16
        }
    }

    private var nameFont: Font {
        switch mode {
        case .display:
            .body
        case .removable, .detail:
            .subheadline
        }
    }

    private var nameColor: Color {
        switch mode {
        case .display:
            .primary
        case .removable, .detail:
            partnerColor
        }
    }

    var body: some View {
        HStack(spacing: spacing) {
            leadingContent
            nameText
            trailingContent
        }
        .padding(.horizontal, 12)
        .padding(.vertical, verticalPadding)
        .background(partnerColor.opacity(0.15))
        .cornerRadius(cornerRadius)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leadingContent: some View {
        switch mode {
        case .display:
            PartnerAvatar(color: partnerColor, initials: partner.initials, size: 32)
        case .detail(let positionIcon, _):
            if let icon = positionIcon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(partnerColor.opacity(0.8))
            }
        case .removable:
            EmptyView()
        }
    }

    private var nameText: some View {
        Text(partner.name)
            .font(nameFont)
            .fontWeight(.medium)
            .lineLimit(1)
            .foregroundColor(nameColor)
    }

    @ViewBuilder
    private var trailingContent: some View {
        switch mode {
        case .removable(let onRemove):
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
        case .detail(_, let hadOrgasm):
            if hadOrgasm {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundColor(partnerColor.opacity(0.8))
            }
        case .display:
            EmptyView()
        }
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
    
    VStack(spacing: 12) {
        PartnerChip(partner: partner, mode: .removable(onRemove: {}))
        PartnerChip(partner: partner, mode: .detail(positionIcon: "figure.stand", hadOrgasm: true))
        PartnerChip(partner: partner, mode: .detail(positionIcon: nil, hadOrgasm: false))
        PartnerChip(partner: partner, mode: .display)
    }
    .padding()
}
