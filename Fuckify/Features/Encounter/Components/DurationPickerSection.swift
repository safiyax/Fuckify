//
//  DurationPickerSection.swift
//  Fuckify
//
//  Reusable duration picker section for encounter forms
//

import SwiftUI

struct DurationPickerRow: View {
    @Binding var durationHours: Int
    @Binding var durationMinutes: Int

    var body: some View {
        HStack {
            Text("Duration")
            Spacer()
            Picker(selection: $durationHours, label: EmptyView()) {
                ForEach(0..<24) { hour in
                    Text("\(hour)h").tag(hour)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Hours")
            .accessibilityValue("\(durationHours) hours")

            Picker(selection: $durationMinutes, label: EmptyView()) {
                ForEach([0, 15, 30, 45], id: \.self) { minute in
                    Text("\(minute)m").tag(minute)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel("Minutes")
            .accessibilityValue("\(durationMinutes) minutes")
        }
    }
}

struct DurationPickerSection: View {
    @Binding var durationHours: Int
    @Binding var durationMinutes: Int
    
    var body: some View {
        Section("When") {
            DurationPickerRow(durationHours: $durationHours, durationMinutes: $durationMinutes)
        }
    }
}

#Preview {
    Form {
        DurationPickerSection(durationHours: .constant(1), durationMinutes: .constant(30))
    }
}
