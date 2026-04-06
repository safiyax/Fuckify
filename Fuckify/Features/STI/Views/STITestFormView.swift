//
//  STITestFormView.swift
//  Fuckify
//
//  Sheet for adding or editing an STI test record.
//

import SwiftUI

struct STITestFormView: View {
    @Environment(STIManager.self) private var stiManager
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing test to edit; nil to create new
    var existingTest: SQLSTITest? = nil

    @State private var date: Date = Date()
    @State private var selectedResultTypeId: UUID? = nil
    @State private var notes: String = ""
    @State private var isSaving = false

    private var isEditing: Bool { existingTest != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Test Date") {
                    DatePicker(
                        "Date",
                        selection: $date,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                }

                Section("Result") {
                    if stiManager.resultTypes.isEmpty {
                        Text("No result types available. Enable some in Settings.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else if stiManager.resultTypes.count <= 3 {
                        // Segmented picker for ≤3 options
                        Picker("Result", selection: $selectedResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Text(type.name).tag(Optional(type.id))
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        // Menu picker for >3 options
                        Picker("Result", selection: $selectedResultTypeId) {
                            ForEach(stiManager.resultTypes) { type in
                                Label(type.name, systemImage: type.icon).tag(Optional(type.id))
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Test" : "Log STI Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(selectedResultTypeId == nil || isSaving)
                }
            }
            .onAppear {
                if let test = existingTest {
                    date = test.date
                    selectedResultTypeId = test.resultTypeId
                    notes = test.notes
                } else {
                    // Default to first enabled result type
                    selectedResultTypeId = stiManager.resultTypes.first?.id
                }
            }
            .onChange(of: stiManager.resultTypes) { _, newTypes in
                if selectedResultTypeId == nil, let first = newTypes.first {
                    selectedResultTypeId = first.id
                }
            }
        }
    }

    private func save() {
        guard let resultTypeId = selectedResultTypeId else { return }
        isSaving = true
        Task {
            defer { isSaving = false }
            if let test = existingTest {
                var updated = test
                updated.date = date
                updated.resultTypeId = resultTypeId
                updated.notes = notes
                await stiManager.updateTest(updated)
            } else {
                await stiManager.addTest(date: date, resultTypeId: resultTypeId, notes: notes)
            }
            dismiss()
        }
    }
}

#Preview {
    STITestFormView()
        .environment(STIManager())
}
