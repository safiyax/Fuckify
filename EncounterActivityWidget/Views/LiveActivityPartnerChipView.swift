//
//  LiveActivityPartnerChipView.swift
//  EncounterActivityWidget
//
//  Partner chip for Live Activity UI (simplified, no interactions)
//

import SwiftUI

struct LiveActivityPartnerChipView: View {
    let partner: PartnerData
    let isCompact: Bool
    
    init(partner: PartnerData, isCompact: Bool = false) {
        self.partner = partner
        self.isCompact = isCompact
    }
    
    var body: some View {
        if isCompact {
            compactView
        } else {
            standardView
        }
    }
    
    private var standardView: some View {
        Text(partner.name)
            .font(.caption)
            .fontWeight(.medium)
            .lineLimit(1)
            .foregroundColor(partnerColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                partnerColor.opacity(0.15)
            )
            .cornerRadius(12)
    }
    
    private var compactView: some View {
        Text(partner.initials)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(width: 24, height: 24)
            .background(partnerColor)
            .clipShape(Circle())
    }
    
    private var partnerColor: Color {
        partner.color
    }
}

/// Special chip for showing "+N more partners"
struct OverflowPartnerChip: View {
    let count: Int
    
    var body: some View {
        Text("+\(count)")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Color.secondary.opacity(0.15)
            )
            .cornerRadius(12)
    }
}
