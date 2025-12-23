//
//  ChartsView.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2025-12-22.
//

import SwiftUI
import SwiftData
import Charts

struct ChartsView: View {
    @Query private var encounters: [Encounter]

    // Data structure for chart
    struct MonthData: Identifiable {
        let id = UUID()
        let month: String
        let monthNumber: Int
        let count: Int
    }

    // Computed property to aggregate encounters by month
    private var encountersByMonth: [MonthData] {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // Create a dictionary to count encounters per month
        var monthCounts: [Int: Int] = [:]

        // Count encounters for each month of the current year
        for encounter in encounters {
            let year = calendar.component(.year, from: encounter.date)
            if year == currentYear {
                let month = calendar.component(.month, from: encounter.date)
                monthCounts[month, default: 0] += 1
            }
        }

        // Create array of all months with their counts
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return (1...12).map { monthNum in
            MonthData(
                month: monthNames[monthNum - 1],
                monthNumber: monthNum,
                count: monthCounts[monthNum] ?? 0
            )
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Encounters per Month Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Encounters per Month")
                            .font(.headline)
                            .padding(.horizontal)

                        Chart(encountersByMonth) { data in
                            BarMark(
                                x: .value("Month", data.month),
                                y: .value("Count", data.count)
                            )
                            .foregroundStyle(.pink.gradient)
                        }
                        .frame(height: 250)
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Statistics")
        }
    }
}

#Preview {
    ChartsView()
        .modelContainer(for: Encounter.self, inMemory: true)
}
