//
//  StatisticsView.swift
//  Fuckify
//
//  Statistics view using SQLiteData
//

import SwiftUI
import SQLiteData
import Dependencies

struct StatisticsView: View {
    @FetchAll
    private var encounters: [SQLEncounter]
    
    @FetchAll
    private var partners: [SQLPartner]
    
    @Dependency(\.encounterService) var encounterService

    @State private var selectedYear: Int? = nil // nil means "All"
    @State private var encounterRelationships: [UUID: EncounterRelationships] = [:]

    // MARK: - Year Filtering

    private var availableYears: [Int] {
        let calendar = Calendar.current
        let years: Set<Int> = Set(encounters.compactMap { encounter in
            guard let date = encounter.date else { return nil }
            return calendar.component(.year, from: date)
        })
        return years.sorted(by: >)
    }

    private var filteredEncounters: [SQLEncounter] {
        guard let year = selectedYear else { return encounters }
        let calendar = Calendar.current
        return encounters.filter { encounter in
            guard let date = encounter.date else { return false }
            return calendar.component(.year, from: date) == year
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overview Stats
                    VStack(spacing: 12) {
                        Text("Overview")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(
                                title: "Total Encounters",
                                value: "\(filteredEncounters.count)",
                                icon: "heart.fill",
                                color: .pink
                            )

                            StatCard(
                                title: "Partners",
                                value: "\(partners.count)",
                                icon: "person.2.fill",
                                color: .blue
                            )

                            StatCard(
                                title: "Avg Duration",
                                value: averageDuration,
                                icon: "clock.fill",
                                color: .orange
                            )

                            StatCard(
                                title: "Recent (30d)",
                                value: "\(recentEncountersCount)",
                                icon: "calendar",
                                color: .green
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Top Activities
                    if !topActivities.isEmpty {
                        VStack(spacing: 12) {
                            Text("Top Activities")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(Array(topActivities.enumerated()), id: \.element.activity) { index, item in
                                    HStack {
                                        Image(systemName: item.activity.icon)
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                            .frame(width: 50, height: 50)
                                            .background(Color.purple.opacity(0.1))
                                            .clipShape(Circle())

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.activity.displayName)
                                                .font(.headline)
                                            Text("\(item.count) times")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text("#\(index + 1)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Top Partners
                    if !topPartners.isEmpty {
                        VStack(spacing: 12) {
                            Text("Most Active Partners")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(Array(topPartners.enumerated()), id: \.element.partner.id) { index, item in
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(item.partner.color)
                                                .frame(width: 50, height: 50)

                                            Text(item.partner.initials)
                                                .font(.headline)
                                                .foregroundColor(.white)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.partner.name)
                                                .font(.headline)
                                            Text("\(item.count) encounters")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Text("#\(index + 1)")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.secondary.opacity(0.5))
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // Protection Methods
                    if let mostCommon = mostCommonProtection {
                        VStack(spacing: 12) {
                            Text("Protection")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            HStack {
                                Image(systemName: mostCommon.method.icon)
                                    .font(.title)
                                    .foregroundColor(.green)
                                    .frame(width: 50, height: 50)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mostCommon.method.displayName)
                                        .font(.headline)
                                    Text("Used in \(mostCommon.count) encounters")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }

                    // Average Rating
                    if averageRating > 0 {
                        VStack(spacing: 12) {
                            Text("Average Rating")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            HStack {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= Int(averageRating.rounded()) ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .font(.title2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Text(String(format: "%.1f", averageRating))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }


                    if !filteredEncounters.isEmpty {
                        EncountersByMonthChartView(selectedYear: selectedYear)

                        EncountersByDayChartView(selectedYear: selectedYear)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            Text("No Data Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Start logging encounters to see your statistics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Summary")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            selectedYear = nil
                        } label: {
                            HStack {
                                Text("All Years")
                                if selectedYear == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }

                        Divider()

                        ForEach(availableYears, id: \.self) { year in
                            Button {
                                selectedYear = year
                            } label: {
                                HStack {
                                    Text(String(year))
                                    if selectedYear == year {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(selectedYear.map(String.init) ?? "All")
                        }
                    }
                }
            }
            .task {
                await loadEncounterRelationships()
            }
        }
    }

    // MARK: - Data Loading
    
    private func loadEncounterRelationships() async {
        for encounter in encounters {
            do {
                let activities = try encounterService.fetchActivities(for: encounter.id)
                let protectionMethods = try encounterService.fetchProtectionMethods(for: encounter.id)
                let partners = try encounterService.fetchPartners(for: encounter.id)
                
                encounterRelationships[encounter.id] = EncounterRelationships(
                    activities: activities,
                    protectionMethods: protectionMethods,
                    partnerIDs: partners.map(\.id)
                )
            } catch {
                // Silent fail
            }
        }
    }

    // MARK: - Computed Properties

    private var averageDuration: String {
        guard !filteredEncounters.isEmpty else { return "0m" }
        let totalDuration = filteredEncounters.reduce(0) { $0 + $1.duration }
        let avgDuration = totalDuration / Double(filteredEncounters.count)

        let hours = Int(avgDuration) / 3600
        let minutes = (Int(avgDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private var recentEncountersCount: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return filteredEncounters.filter { encounter in
            guard let date = encounter.date else { return false }
            return date >= thirtyDaysAgo
        }.count
    }

    private var topActivities: [(activity: SQLActivityType, count: Int)] {
        let allActivities = filteredEncounters.compactMap { encounterRelationships[$0.id]?.activities }.flatMap { $0 }
        guard !allActivities.isEmpty else { return [] }

        let counts = Dictionary(grouping: allActivities) { $0 }
            .mapValues { $0.count }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (activity: $0.key, count: $0.value) }
    }

    private var mostCommonProtection: (method: SQLProtectionMethod, count: Int)? {
        let allProtection = filteredEncounters.compactMap { encounterRelationships[$0.id]?.protectionMethods }.flatMap { $0 }
        guard !allProtection.isEmpty else { return nil }

        let counts = Dictionary(grouping: allProtection) { $0 }
            .mapValues { $0.count }
        guard let mostCommon = counts.max(by: { $0.value < $1.value }) else { return nil }

        return (mostCommon.key, mostCommon.value)
    }

    private var topPartners: [(partner: SQLPartner, count: Int)] {
        let allPartnerIDs = filteredEncounters.compactMap { encounterRelationships[$0.id]?.partnerIDs }.flatMap { $0 }
        guard !allPartnerIDs.isEmpty else { return [] }

        let counts = Dictionary(grouping: allPartnerIDs) { $0 }
            .mapValues { $0.count }

        return counts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { id, count in
                guard let partner = partners.first(where: { $0.id == id }) else { return nil }
                return (partner: partner, count: count)
            }
    }

    private var averageRating: Double {
        let ratedEncounters = filteredEncounters.filter { $0.rating > 0 }
        guard !ratedEncounters.isEmpty else { return 0 }

        let totalRating = ratedEncounters.reduce(0) { $0 + $1.rating }
        return Double(totalRating) / Double(ratedEncounters.count)
    }
}

// MARK: - Helper Types

struct EncounterRelationships {
    let activities: [SQLActivityType]
    let protectionMethods: [SQLProtectionMethod]
    let partnerIDs: [UUID]
}

// MARK: - Stat Card View

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    let _ = prepareDependencies {
        $0.defaultDatabase = try! appDatabase()
    }
    
    return StatisticsView()
}
