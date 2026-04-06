//
//  STITestDetailView.swift
//  Fuckify
//
//  Detail view for a single STI test. Supports inline editing (mirrors PartnerDetailView pattern).
//

import SwiftUI

struct STITestDetailView: View {
    let test: SQLSTITest

    @Environment(STIManager.self) private var stiManager
    @Environment(\.editMode) private var editMode

    @State private var editDate: Date = Date()
    @State private var editResultTypeId: UUID? = nil
    @State private var editNotes: String = ""
    @Environment(\.dismiss) private var dismiss

    private var isEditing: Bool { editMode?.wrappedValue.isEditing == true }

    private var resultType: SQLSTITestResultType? {
        // First try to find by exact ID (handles enabled types)
        // Fallback: show first available type if the test's type was disabled
        stiManager.resultTypes.first { $0.id == test.resultTypeId }
    }

    var body: some View {
        List {
            Section("Test Date") {
                if isEditing {
                    DatePicker(
                        "Date",
                        selection: $editDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                } else {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(test.date.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Result") {
                if isEditing {
                    if stiManager.resultTypes.count <= 3 {
                        Picker("Result", selection: $editResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Text(type.name).tag(Optional(type.id))
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Picker("Result", selection: $editResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Label(type.name, systemImage: type.icon).tag(Optional(type.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } else {
                    if let rt = resultType {
                        HStack {
                            Image(systemName: rt.icon)
                                .foregroundStyle(rt.displayColor)
                            Text(rt.name)
                                .fontWeight(.medium)
                                .foregroundStyle(rt.displayColor)
                        }
                    }
                }
            }

            Section("Notes") {
                if isEditing {
                    TextField("Optional notes", text: $editNotes, axis: .vertical)
                        .lineLimit(3...6)
                } else if test.notes.isEmpty {
                    Text("No notes")
                        .foregroundStyle(.secondary)
                } else {
                    Text(test.notes)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(test.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onChange(of: editMode?.wrappedValue) { _, newValue in
            if newValue?.isEditing == true {
                editDate = test.date
                editResultTypeId = test.resultTypeId
                editNotes = test.notes
            } else if newValue?.isEditing == false {
                saveIfChanged()
            }
        }
    }

    private func saveIfChanged() {
        guard let resultTypeId = editResultTypeId else { return }
        var updated = test
        updated.date = editDate
        updated.resultTypeId = resultTypeId
        updated.notes = editNotes
        Task { await stiManager.updateTest(updated) }
    }
}

#Preview {
    NavigationStack {
        STITestDetailView(
            test: SQLSTITest(
                id: UUID(),
                date: Date(),
                resultTypeId: SQLSTITestResultType.negativeId,
                notes: "All clear"
            )
        )
        .environment(STIManager())
    }
}
