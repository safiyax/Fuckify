//
//  ChartsView.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2025-12-22.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - Encounters by Month Chart

struct EncountersByMonthChartView: View {
    @Query private var encounters: [Encounter]
    @Query private var partners: [Partner]

    var selectedYear: Int? = nil // nil means all years

    // Data structure for stacked chart
    struct PartnerMonthData: Identifiable {
        let id = UUID()
        let month: String
        let monthNumber: Int
        let partnerName: String
        let partnerColor: Color
        let count: Int
    }

    // Get top 4 partners by encounter count
    private var topPartners: [Partner] {
        let partnerCounts = Dictionary(grouping: encounters) { encounter -> String in
            guard let partners = encounter.partners, let firstPartner = partners.first else {
                return "Unknown"
            }
            return firstPartner.persistentModelID.hashValue.description
        }

        let sortedPartners = partners.sorted { p1, p2 in
            let count1 = encounters.filter { encounter in
                encounter.partners?.contains(where: { $0.persistentModelID == p1.persistentModelID }) ?? false
            }.count
            let count2 = encounters.filter { encounter in
                encounter.partners?.contains(where: { $0.persistentModelID == p2.persistentModelID }) ?? false
            }.count
            return count1 > count2
        }

        return Array(sortedPartners.prefix(4))
    }

    // Computed property to aggregate encounters by month and partner
    private var encountersByMonthAndPartner: [PartnerMonthData] {
        let calendar = Calendar.current
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        let top4 = topPartners
        let top4IDs = Set(top4.map { $0.persistentModelID })

        // Filter encounters by selected year
        let filteredEncounters: [Encounter]
        if let year = selectedYear {
            filteredEncounters = encounters.filter { calendar.component(.year, from: $0.date) == year }
        } else {
            filteredEncounters = encounters
        }

        // Dictionary to store counts: [monthKey: [partnerName: count]]
        // monthKey is "YYYY-MM" for all years or "MM" for single year
        var monthPartnerCounts: [String: [String: Int]] = [:]
        var monthKeys: Set<String> = []

        // Count encounters for each month and partner
        for encounter in filteredEncounters {
            let year = calendar.component(.year, from: encounter.date)
            let month = calendar.component(.month, from: encounter.date)

            // Create month key based on whether we're showing all years or just one
            let monthKey: String
            if selectedYear == nil {
                monthKey = String(format: "%04d-%02d", year, month)
            } else {
                monthKey = String(format: "%02d", month)
            }
            monthKeys.insert(monthKey)

            if monthPartnerCounts[monthKey] == nil {
                monthPartnerCounts[monthKey] = [:]
            }

            // Determine which partner category this encounter belongs to
            if let encounterPartners = encounter.partners, !encounterPartners.isEmpty {
                let isTopPartner = encounterPartners.contains { top4IDs.contains($0.persistentModelID) }

                if isTopPartner, let partner = encounterPartners.first(where: { top4IDs.contains($0.persistentModelID) }) {
                    monthPartnerCounts[monthKey]?[partner.name, default: 0] += 1
                } else {
                    monthPartnerCounts[monthKey]?["Others", default: 0] += 1
                }
            } else {
                monthPartnerCounts[monthKey]?["Others", default: 0] += 1
            }
        }

        // Create array of all months and partners with their counts
        var result: [PartnerMonthData] = []

        if let year = selectedYear {
            // Show 12 months for the selected year
            for monthNum in 1...12 {
                let monthKey = String(format: "%02d", monthNum)
                let monthName = monthNames[monthNum - 1]
                let partnersForMonth = monthPartnerCounts[monthKey] ?? [:]

                // Add entries for top 4 partners
                for partner in top4 {
                    let count = partnersForMonth[partner.name] ?? 0
                    result.append(PartnerMonthData(
                        month: monthName,
                        monthNumber: monthNum,
                        partnerName: partner.name,
                        partnerColor: partner.color,
                        count: count
                    ))
                }

                // Add entry for "Others"
                let othersCount = partnersForMonth["Others"] ?? 0
                result.append(PartnerMonthData(
                    month: monthName,
                    monthNumber: monthNum,
                    partnerName: "Others",
                    partnerColor: .accent,
                    count: othersCount
                ))
            }
        } else {
            // Show all months across all years
            let sortedKeys = monthKeys.sorted()
            for (index, monthKey) in sortedKeys.enumerated() {
                let components = monthKey.split(separator: "-")
                let year = Int(components[0]) ?? 0
                let monthNum = Int(components[1]) ?? 0
                let monthName = monthNames[(monthNum - 1) % 12] + " '\(String(year).suffix(2))"
                let partnersForMonth = monthPartnerCounts[monthKey] ?? [:]

                // Add entries for top 4 partners
                for partner in top4 {
                    let count = partnersForMonth[partner.name] ?? 0
                    result.append(PartnerMonthData(
                        month: monthName,
                        monthNumber: index + 1, // Use sequential number for proper ordering
                        partnerName: partner.name,
                        partnerColor: partner.color,
                        count: count
                    ))
                }

                // Add entry for "Others"
                let othersCount = partnersForMonth["Others"] ?? 0
                result.append(PartnerMonthData(
                    month: monthName,
                    monthNumber: index + 1,
                    partnerName: "Others",
                    partnerColor: .accent,
                    count: othersCount
                ))
            }
        }

        return result
    }

    // Create color mapping for chart
    private var partnerColorMapping: KeyValuePairs<String, Color> {
        var pairs: [(String, Color)] = []
        var seen = Set<String>()

        for data in encountersByMonthAndPartner {
            if !seen.contains(data.partnerName) {
                pairs.append((data.partnerName, data.partnerColor))
                seen.insert(data.partnerName)
            }
        }

        // Convert to KeyValuePairs format
        switch pairs.count {
        case 0: return [:]
        case 1: return [pairs[0].0: pairs[0].1]
        case 2: return [pairs[0].0: pairs[0].1, pairs[1].0: pairs[1].1]
        case 3: return [pairs[0].0: pairs[0].1, pairs[1].0: pairs[1].1, pairs[2].0: pairs[2].1]
        case 4: return [pairs[0].0: pairs[0].1, pairs[1].0: pairs[1].1, pairs[2].0: pairs[2].1, pairs[3].0: pairs[3].1]
        default: return [pairs[0].0: pairs[0].1, pairs[1].0: pairs[1].1, pairs[2].0: pairs[2].1, pairs[3].0: pairs[3].1, pairs[4].0: pairs[4].1]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encounters per Month")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Chart(encountersByMonthAndPartner) { data in
                BarMark(
                    x: .value("Month", data.month),
                    y: .value("Count", data.count)
                )
                .foregroundStyle(by: .value("Partner", data.partnerName))
            }
            .chartForegroundStyleScale(partnerColorMapping)
            .padding(.vertical, 4)
            .frame(height: 250)
            .chartXAxis {
                AxisMarks(stroke: StrokeStyle(lineWidth: 0))
            }
            .chartYAxis {
                AxisMarks(position: .leading, stroke: StrokeStyle(lineWidth: 0))
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Encounters by Day of Week Chart



// MARK: - Preview

//#Preview {
//    ChartsView()
//        .modelContainer(for: Encounter.self, inMemory: true)
//}
