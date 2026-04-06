//
//  STIManager.swift
//  Fuckify
//
//  Observable view model for STI test tracking. Mirrors EncountersViewModel pattern.
//

import Foundation
import SwiftUI
import UserNotifications
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "STIManager")

private let reminderNotificationId = "sti-test-reminder"

@MainActor
@Observable
final class STIManager {
    // MARK: - Dependencies

    private let stiService: STIService
    private let stiResultTypeService: STIResultTypeService

    // MARK: - State

    var tests: [SQLSTITest] = []
    var resultTypes: [SQLSTITestResultType] = []
    var errorMessage: String?
    var reminderDenied: Bool = false
    var isLoading = false

    // MARK: - Computed Properties

    var latestTest: SQLSTITest? { tests.first }

    var daysSinceLastTest: Int? {
        guard let latest = latestTest else { return nil }
        return Calendar.current.dateComponents([.day], from: latest.date, to: Date()).day
    }

    private var testingIntervalDays: Int {
        let v = UserDefaults.standard.integer(forKey: "stiTestingIntervalDays")
        return v > 0 ? v : 90
    }

    var nextTestDueDate: Date? {
        let days = testingIntervalDays
        guard let latest = latestTest else {
            // No tests — schedule from today
            return Calendar.current.date(byAdding: .day, value: days, to: Date())
        }
        let candidate = Calendar.current.date(byAdding: .day, value: days, to: latest.date)
        guard let c = candidate, c > Date() else { return nil }
        return c
    }

    var daysUntilNextTest: Int? {
        guard let next = nextTestDueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: next).day
    }

    /// Color for "days since last test" status (uses user-configured testing interval)
    var statusColor: Color {
        guard let days = daysSinceLastTest else { return .red }
        let interval = testingIntervalDays
        if days < interval { return .green }
        if days < interval * 2 { return .orange }
        return .red
    }

    var statusIcon: String {
        guard let days = daysSinceLastTest else { return "exclamationmark.triangle.fill" }
        let interval = testingIntervalDays
        if days < interval { return "checkmark.circle.fill" }
        if days < interval * 2 { return "exclamationmark.circle.fill" }
        return "exclamationmark.triangle.fill"
    }

    // MARK: - Init

    nonisolated init(
        stiService: STIService = STIService(),
        stiResultTypeService: STIResultTypeService = STIResultTypeService()
    ) {
        self.stiService = stiService
        self.stiResultTypeService = stiResultTypeService
    }

    // MARK: - Data Operations

    func load() async {
        isLoading = true
        do {
            tests = try stiService.fetchAll()
            resultTypes = try stiResultTypeService.fetchAll()
        } catch {
            logger.error("Failed to load STI data: \(error.localizedDescription)")
            errorMessage = "Unable to load STI test history."
        }
        isLoading = false
    }

    func addTest(date: Date, resultTypeId: UUID, notes: String) async {
        do {
            _ = try stiService.create(date: date, resultTypeId: resultTypeId, notes: notes)
            await load()
            await rescheduleReminderIfEnabled()
        } catch {
            logger.error("Failed to create STI test: \(error.localizedDescription)")
            errorMessage = "Unable to save test. Please try again."
        }
    }

    func updateTest(_ test: SQLSTITest) async {
        do {
            try stiService.update(test)
            await load()
            await rescheduleReminderIfEnabled()
        } catch {
            logger.error("Failed to update STI test: \(error.localizedDescription)")
            errorMessage = "Unable to update test. Please try again."
        }
    }

    func deleteTest(_ id: UUID) async {
        do {
            try stiService.delete(id)
            await load()
            await rescheduleReminderIfEnabled()
        } catch {
            logger.error("Failed to delete STI test: \(error.localizedDescription)")
            errorMessage = "Unable to delete test. Please try again."
        }
    }

    // MARK: - Reminders

    /// Call when user toggles reminders on. Checks permission, schedules if granted.
    func enableReminders() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .denied:
            reminderDenied = true
            logger.warning("Notification permission denied — cannot schedule STI reminder")
        case .authorized, .provisional, .ephemeral:
            reminderDenied = false
            await scheduleReminder()
        case .notDetermined:
            // Should not happen — permission already requested at app launch
            await scheduleReminder()
        @unknown default:
            await scheduleReminder()
        }
    }

    func disableReminders() async {
        await cancelReminder()
    }

    func rescheduleReminderIfEnabled() async {
        let remindersEnabled = UserDefaults.standard.bool(forKey: "stiRemindersEnabled")
        if remindersEnabled {
            await enableReminders()
        }
    }

    private func scheduleReminder() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])

        let days = testingIntervalDays

        let fireDate: Date
        if let latest = latestTest {
            guard let candidate = Calendar.current.date(byAdding: .day, value: days, to: latest.date),
                  candidate > Date() else {
                // Due date already passed — schedule from today
                let fallback = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
                await scheduleNotification(at: fallback, center: center)
                return
            }
            fireDate = candidate
        } else {
            fireDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date().addingTimeInterval(Double(days) * 86400)
        }

        await scheduleNotification(at: fireDate, center: center)
    }

    private func scheduleNotification(at date: Date, center: UNUserNotificationCenter) async {
        let content = UNMutableNotificationContent()
        content.title = "STI Test Reminder"
        content.body = "Time for your STI test. Stay on top of your sexual health."
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: reminderNotificationId, content: content, trigger: trigger)

        do {
            try await center.add(request)
            logger.info("Scheduled STI reminder for \(date)")
        } catch {
            logger.error("Failed to schedule STI reminder: \(error.localizedDescription)")
        }
    }

    private func cancelReminder() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderNotificationId])
        logger.info("Cancelled STI reminder")
    }
}
