//
//  EncountersByDayChartView.swift
//  Fuckify
//
//  Day of week chart using SQLite
//

import SwiftUI
import SQLiteData
import Charts


struct EncountersByDayChartView: View {
    @FetchAll
    private var encounters: [SQLEncounter]

    var selectedYear: Int? = nil // nil means all years

    // Data structure for chart
    struct DayData: Identifiable {
        let id = UUID()
        let day: String
        let dayNumber: Int
        let count: Int
    }

    // Computed property to calculate total encounters by day of week
    private var encountersByDayOfWeek: [DayData] {
        let calendar = Calendar.current
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        // Filter encounters by selected year
        let filteredEncounters: [SQLEncounter]
        if let year = selectedYear {
            filteredEncounters = encounters.filter { encounter in
                guard let date = encounter.date else { return false }
                return calendar.component(.year, from: date) == year
            }
        } else {
            filteredEncounters = encounters
        }

        // Count encounters per day of week
        var dayCounts: [Int: Int] = [:]
        for encounter in filteredEncounters {
            guard let date = encounter.date else { continue }
            let weekday = calendar.component(.weekday, from: date)
            dayCounts[weekday, default: 0] += 1
        }

        // Return total counts for each day
        return (1...7).map { dayNum in
            let count = dayCounts[dayNum] ?? 0
            return DayData(day: dayNames[dayNum - 1], dayNumber: dayNum, count: count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Encounters by Day of Week")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            Chart(encountersByDayOfWeek) { data in
                BarMark(
                    x: .value("Day", data.day),
                    y: .value("Count", data.count)
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
