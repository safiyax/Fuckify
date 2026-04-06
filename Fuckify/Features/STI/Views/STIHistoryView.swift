//
//  STIHistoryView.swift
//  Fuckify
//
//  Full STI test history with timeline, reminders section, and summary header.
//

import SwiftUI

struct STIHistoryView: View {
    @Environment(STIManager.self) private var stiManager
    @Environment(UserProfile.self) private var profile

    @State private var showingAddForm = false
    @State private var testToDelete: SQLSTITest? = nil
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            // Summary Header
            summaryHeaderSection

            // Reminders Section
            remindersSection

            // Timeline or Empty State
            if stiManager.tests.isEmpty {
                emptyStateSection
            } else {
                timelineSection
            }
        }
        .navigationTitle("Sexual Health")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Test", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            STITestFormView()
                .dismissOnAppLock()
        }
        .alert("Delete Test", isPresented: $showingDeleteAlert, presenting: testToDelete) { test in
            Button("Delete", role: .destructive) {
                Task { await stiManager.deleteTest(test.id) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { test in
            Text("Delete the test from \(test.date.formatted(date: .abbreviated, time: .omitted))?")
        }
        .task { await stiManager.load() }
    }

    // MARK: - Summary Header

    private var summaryHeaderSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                if let latest = stiManager.latestTest {
                    HStack {
                        Label("Last Test", systemImage: stiManager.statusIcon)
                            .foregroundStyle(stiManager.statusColor)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.medium)
                            if let days = stiManager.daysSinceLastTest {
                                Text("\(days) days ago")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    if let nextDate = stiManager.nextTestDueDate, let daysUntil = stiManager.daysUntilNextTest {
                        Divider()
                        HStack {
                            Label("Next Test Due", systemImage: "bell.badge")
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(nextDate.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.medium)
                                Text("in \(daysUntil) days")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                } else {
                    HStack {
                        Label("No tests logged yet", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Reminders Section

    @ViewBuilder
    private var remindersSection: some View {
        @Bindable var bindableProfile = profile

        Section("Reminders") {
            Toggle("Test Reminders", isOn: Binding(
                get: { profile.stiRemindersEnabled },
                set: { enabled in
                    profile.stiRemindersEnabled = enabled
                    Task {
                        if enabled {
                            await stiManager.enableReminders()
                            // If permission was denied, revert the toggle
                            if stiManager.reminderDenied {
                                profile.stiRemindersEnabled = false
                            }
                        } else {
                            await stiManager.disableReminders()
                        }
                    }
                }
            ))

            if profile.stiRemindersEnabled {
                Picker("Testing Interval", selection: $bindableProfile.stiTestingIntervalDays) {
                    Text("Every 30 days").tag(30)
                    Text("Every 60 days").tag(60)
                    Text("Every 90 days").tag(90)
                    Text("Every 180 days").tag(180)
                }
                .onChange(of: profile.stiTestingIntervalDays) { _, _ in
                    Task {
                        await stiManager.rescheduleReminderIfEnabled()
                        await stiManager.load()
                    }
                }
            }

            if stiManager.reminderDenied {
                HStack {
                    Image(systemName: "bell.slash.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications Disabled")
                            .fontWeight(.medium)
                        Text("Enable notifications in Settings to receive reminders.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        Section("Test History") {
            ForEach(stiManager.tests) { test in
                let index = stiManager.tests.firstIndex(where: { $0.id == test.id })!
                let nextTest = index + 1 < stiManager.tests.count ? stiManager.tests[index + 1] : nil
                let nextResultType = nextTest.flatMap { next in
                    stiManager.resultTypes.first { $0.id == next.resultTypeId }
                }
                NavigationLink(destination: STITestDetailView(test: test)) {
                    TimelineRowView(
                        test: test,
                        resultType: stiManager.resultTypes.first { $0.id == test.resultTypeId },
                        nextResultType: nextResultType,
                        isLast: test.id == stiManager.tests.last?.id
                    )
                }
                .navigationLinkIndicatorVisibility(.hidden)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        testToDelete = test
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "cross.case")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue.opacity(0.5))
                Text("No tests logged yet")
                    .font(.headline)
                Text("Log your STI tests to track your sexual health history.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    showingAddForm = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Log First Test")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .listRowBackground(Color.clear)
    }
}

// MARK: - Timeline Row

private struct TimelineRowView: View {
    let test: SQLSTITest
    let resultType: SQLSTITestResultType?
    let nextResultType: SQLSTITestResultType?
    let isLast: Bool

    private var dotColor: Color {
        resultType?.displayColor ?? .gray
    }

    private var nextDotColor: Color {
        nextResultType?.displayColor ?? .gray
    }

    private var icon: String {
        resultType?.icon ?? "questionmark"
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            // Circle with icon + vertical connector line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                if !isLast {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [dotColor, nextDotColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 44)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(test.date.formatted(date: .abbreviated, time: .omitted))
                    .fontWeight(.semibold)
                if !test.notes.isEmpty {
                    Text(test.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, isLast ? 28 : 44)

            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    NavigationStack {
        STIHistoryView()
            .environment(STIManager())
            .environment(UserProfile())
    }
}
