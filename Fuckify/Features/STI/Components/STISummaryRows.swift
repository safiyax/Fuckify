import SwiftUI

struct STISummaryRows: View {
    let manager: STIManager
    let lastTestTitle: LocalizedStringKey
    let colorEntireLastTestRow: Bool

    init(
        manager: STIManager,
        lastTestTitle: LocalizedStringKey = "Last Test",
        colorEntireLastTestRow: Bool = false
    ) {
        self.manager = manager
        self.lastTestTitle = lastTestTitle
        self.colorEntireLastTestRow = colorEntireLastTestRow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if colorEntireLastTestRow {
                HStack {
                    Label(lastTestTitle, systemImage: manager.statusIcon)
                    Spacer()
                    if let days = manager.daysSinceLastTest,
                       let latest = manager.latestTest {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.medium)
                            Text("\(days) days ago")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(manager.statusColor)
            } else {
                HStack {
                    Label(lastTestTitle, systemImage: manager.statusIcon)
                        .foregroundStyle(manager.statusColor)
                    Spacer()
                    if let days = manager.daysSinceLastTest,
                       let latest = manager.latestTest {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                .fontWeight(.medium)
                            Text("\(days) days ago")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if let nextDate = manager.nextTestDueDate,
               let daysUntil = manager.daysUntilNextTest {
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
        }
    }
}
