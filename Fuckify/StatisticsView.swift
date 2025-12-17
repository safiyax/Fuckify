//
//  StatisticsView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var encounters: [Encounter]
    @Query private var partners: [Partner]
    @State private var showingSettings = false

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
                                value: "\(encounters.count)",
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

                    // Most Common Activity
                    if let mostCommonActivity = mostCommonActivity {
                        VStack(spacing: 12) {
                            Text("Most Common Activity")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            HStack {
                                Image(systemName: mostCommonActivity.activity.icon)
                                    .font(.title)
                                    .foregroundColor(.purple)
                                    .frame(width: 60, height: 60)
                                    .background(Color.purple.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mostCommonActivity.activity.displayName)
                                        .font(.headline)
                                    Text("\(mostCommonActivity.count) times")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }

                    // Most Common Protection
                    if let mostCommonProtection = mostCommonProtection {
                        VStack(spacing: 12) {
                            Text("Most Common Protection")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            HStack {
                                Image(systemName: mostCommonProtection.method.icon)
                                    .font(.title)
                                    .foregroundColor(.green)
                                    .frame(width: 60, height: 60)
                                    .background(Color.green.opacity(0.1))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mostCommonProtection.method.displayName)
                                        .font(.headline)
                                    Text("\(mostCommonProtection.count) times")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }

                    // Top Partner
                    if let topPartner = topPartner {
                        VStack(spacing: 12) {
                            Text("Most Frequent Partner")
                                .font(.title2)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)

                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(topPartner.partner.color)
                                        .frame(width: 60, height: 60)

                                    Text(topPartner.partner.initials)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(topPartner.partner.name)
                                        .font(.headline)
                                    Text("\(topPartner.count) encounters")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
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

                    if encounters.isEmpty {
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
            .navigationTitle("Statistics")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Computed Properties

    private var averageDuration: String {
        guard !encounters.isEmpty else { return "0m" }
        let totalDuration = encounters.reduce(0) { $0 + $1.duration }
        let avgDuration = totalDuration / Double(encounters.count)

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
        return encounters.filter { $0.date >= thirtyDaysAgo }.count
    }

    private var mostCommonActivity: (activity: ActivityType, count: Int)? {
        let allActivities = encounters.flatMap { $0.activities }
        guard !allActivities.isEmpty else { return nil }

        let counts = Dictionary(grouping: allActivities) { $0 }
            .mapValues { $0.count }
        guard let mostCommon = counts.max(by: { $0.value < $1.value }) else { return nil }

        return (mostCommon.key, mostCommon.value)
    }

    private var mostCommonProtection: (method: ProtectionMethod, count: Int)? {
        let allProtection = encounters.flatMap { $0.protectionMethods }
        guard !allProtection.isEmpty else { return nil }

        let counts = Dictionary(grouping: allProtection) { $0 }
            .mapValues { $0.count }
        guard let mostCommon = counts.max(by: { $0.value < $1.value }) else { return nil }

        return (mostCommon.key, mostCommon.value)
    }

    private var topPartner: (partner: Partner, count: Int)? {
        let allPartners = encounters.compactMap { $0.partners }.flatMap { $0 }
        guard !allPartners.isEmpty else { return nil }

        let counts = Dictionary(grouping: allPartners) { $0.id }
            .mapValues { $0.count }
        guard let mostCommon = counts.max(by: { $0.value < $1.value }),
              let partner = allPartners.first(where: { $0.id == mostCommon.key }) else { return nil }

        return (partner, mostCommon.value)
    }

    private var averageRating: Double {
        let ratedEncounters = encounters.filter { $0.rating > 0 }
        guard !ratedEncounters.isEmpty else { return 0 }

        let totalRating = ratedEncounters.reduce(0) { $0 + $1.rating }
        return Double(totalRating) / Double(ratedEncounters.count)
    }
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
    StatisticsView()
        .modelContainer(for: [Encounter.self, Partner.self], inMemory: true)
}
