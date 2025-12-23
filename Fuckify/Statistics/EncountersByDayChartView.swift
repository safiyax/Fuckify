//
//  EncountersByDayChartView.swift
//  Fuckify
//
//  Created by Zeeshan Hooda on 2025-12-22.
//

import SwiftUI
import SwiftData
import Charts


struct EncountersByDayChartView: View {
    @Query private var encounters: [Encounter]

    // Data structure for chart
    struct DayData: Identifiable {
        let id = UUID()
        let day: String
        let dayNumber: Int
        let average: Double
    }

    // Computed property to calculate average encounters by day of week
    private var encountersByDayOfWeek: [DayData] {
        let calendar = Calendar.current
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        guard !encounters.isEmpty else {
            return (1...7).map { dayNum in
                DayData(day: dayNames[dayNum - 1], dayNumber: dayNum, average: 0)
            }
        }

        // Find the date range
        let sortedDates = encounters.map { $0.date }.sorted()
        guard let firstDate = sortedDates.first,
              let lastDate = sortedDates.last else {
            return []
        }

        // Count encounters per day of week
        var dayCounts: [Int: Int] = [:]
        for encounter in encounters {
            let weekday = calendar.component(.weekday, from: encounter.date)
            dayCounts[weekday, default: 0] += 1
        }

        // Calculate number of occurrences of each weekday in the date range
        var dayOccurrences: [Int: Int] = [:]
        var currentDate = firstDate
        while currentDate <= lastDate {
            let weekday = calendar.component(.weekday, from: currentDate)
            dayOccurrences[weekday, default: 0] += 1
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        // Calculate averages
        return (1...7).map { dayNum in
            let count = Double(dayCounts[dayNum] ?? 0)
            let occurrences = Double(dayOccurrences[dayNum] ?? 1)
            let average = occurrences > 0 ? count / occurrences : 0
            return DayData(day: dayNames[dayNum - 1], dayNumber: dayNum, average: average)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Average Encounters by Day")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Chart(encountersByDayOfWeek) { data in
                BarMark(
                    x: .value("Day", data.day),
                    y: .value("Average", data.average)
                )
                .foregroundStyle(.purple.gradient)
            }
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
    }
}
