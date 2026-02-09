//
//  CalendarEncounterRow.swift
//  Fuckify
//
//  Row component for displaying encounters in calendar view
//

import SwiftUI
import SQLiteData
import Dependencies

struct CalendarEncounterRow: View {
    let encounter: SQLEncounter
    
    @Dependency(\.encounterService) var encounterService
    @State private var partners: [SQLPartner] = []
    @State private var activityEntities: [SQLActivityTypeEntity] = []
    @State private var protectionEntities: [SQLProtectionMethodEntity] = []
    
    var body: some View {
        HStack(spacing: 12) {
            // Time indicator (colored bar with partner colors)
            partnerColorBar
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    // Partners
                    if !partners.isEmpty {
                        Text(partners.map(\.name).joined(separator: ", "))
                            .font(.headline)
                            .foregroundColor(.primary)
                    } else {
                        Text("No partners")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if encounter.duration > 0 {
                        Text("\(encounter.formattedDuration)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Activities and Protection
                HStack(spacing: 8) {
                    if !activityEntities.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(activityEntities.prefix(4)) { activity in
                                Image(systemName: activity.icon)
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                            }
                            if activityEntities.count > 4 {
                                Text("+\(activityEntities.count - 4)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    if !protectionEntities.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(protectionEntities) { protectionMethod in
                                Image(systemName: protectionMethod.icon)
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .task {
            await loadData()
        }
    }
    
    @ViewBuilder
    private var partnerColorBar: some View {
        let partnerColors = partners.map { Color.fromPartnerColorName($0.avatarColor) }
        
        if partnerColors.isEmpty {
            // Fallback to accent color if no partners
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor)
                .frame(width: 4)
        } else if partnerColors.count == 1 {
            // Single partner - solid color
            RoundedRectangle(cornerRadius: 8)
                .fill(partnerColors[0])
                .frame(width: 4)
        } else {
            // Multiple partners - split vertically
            VStack(spacing: 0) {
                ForEach(0..<partnerColors.count, id: \.self) { index in
                    partnerColors[index]
                }
            }
            .frame(width: 4)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    @MainActor
    private func loadData() async {
        do {
            partners = try encounterService.fetchPartners(for: encounter.id)
            activityEntities = try encounterService
                .fetchActivityEntities(for: encounter.id)
                .sorted { $0.name < $1.name }
            protectionEntities = try encounterService
                .fetchProtectionMethodEntities(for: encounter.id)
                .sorted { $0.name < $1.name }
        } catch {
            // Silent fail
        }
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    let encounter = SQLEncounter(
        id: UUID(),
        date: Date(),
        duration: 3600,
        location: "",
        notes: "",
        rating: 4,
        reachedOrgasm: true,
        dateAdded: Date()
    )
    
    return CalendarEncounterRow(encounter: encounter)
}
