//
//  DebugFlagRow.swift
//  Fuckify
//
//  Reusable row for feature flag toggles in the debug menu.
//  Shows an orange indicator when the value is a local override.
//

import SwiftUI

struct DebugFlagRow: View {
    let label: String
    @Binding var value: Bool
    var isOverridden: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(value ? .green : .red)
                    .font(.body)

                if isOverridden {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }

            Text(label)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Toggle("", isOn: $value)
                .labelsHidden()
        }
    }
}
