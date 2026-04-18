//
//  PartnerImportView.swift
//  Fuckify
//
//

import SwiftUI
import UniformTypeIdentifiers
import Dependencies

private let logger = AppLogger(subsystem: "baby.safi.Fuckify", category: "PartnerImport")

struct PartnerImportView: View {
    @Dependency(\.partnerService) private var partnerService
    @Environment(\.dismiss) private var dismiss

    @State private var showingFilePicker = false
    @State private var importedPartners: [PartnerImportData] = []
    @State private var showingPreview = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if importedPartners.isEmpty {
                    CSVImportInstructionsView(
                        title: "Import Partners from CSV",
                        color: .blue,
                        format: "name,phoneNumber,notes,relationshipType,dateMet",
                        example: "John Doe,555-0123,Met at gym,Regular,2024-01-15",
                        notes: "• Name is required\n• Other fields are optional\n• relationshipType: Casual, Regular, Committed, One-Time, Other\n• dateMet: YYYY-MM-DD format"
                    ) {
                        showingFilePicker = true
                    }
                } else {
                    // Preview imported data
                    List {
                        Section {
                            Text("Found \(importedPartners.count) partner(s) to import")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        ForEach(Array(importedPartners.enumerated()), id: \.offset) { index, partner in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(partner.name)
                                    .font(.headline)

                                if !partner.phoneNumber.isEmpty {
                                    Text("Phone: \(partner.phoneNumber)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Text(partner.relationshipType.displayName)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Import Partners")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !importedPartners.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            importPartners()
                        }
                        .disabled(isImporting)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.commaSeparatedText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Request access to security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access the selected file"
                showingError = true
                return
            }

            // Ensure we stop accessing when done
            defer {
                url.stopAccessingSecurityScopedResource()
            }

            parseCSV(from: url)
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func parseCSV(from url: URL) {
        do {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard lines.count > 1 else {
                errorMessage = "CSV file is empty or only contains headers"
                showingError = true
                return
            }

            // Skip header line
            var partners: [PartnerImportData] = []

            for (index, line) in lines.enumerated() {
                if index == 0 { continue } // Skip header

                let components = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

                guard !components.isEmpty, !components[0].isEmpty else { continue }

                let name = components[0]
                let phoneNumber = components.count > 1 ? components[1] : ""
                let notes = components.count > 2 ? components[2] : ""

                let relationshipType: SQLRelationshipType
                if components.count > 3 {
                    relationshipType = SQLRelationshipType(rawValue: components[3]) ?? .casual
                } else {
                    relationshipType = .casual
                }

                var dateMet: Date? = nil
                if components.count > 4, !components[4].isEmpty {
                    dateMet = parseDate(components[4])
                }

                partners.append(PartnerImportData(
                    name: name,
                    phoneNumber: phoneNumber,
                    notes: notes,
                    relationshipType: relationshipType,
                    dateMet: dateMet
                ))
            }

            if partners.isEmpty {
                errorMessage = "No valid partners found in CSV file"
                showingError = true
            } else {
                importedPartners = partners
            }

        } catch {
            errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func parseDate(_ dateString: String) -> Date? {
        // Use cached formatter with local timezone to avoid date shifting
        return Formatters.csvDateParser.date(from: dateString)
    }

    private func importPartners() {
        isImporting = true

        for partnerData in importedPartners {
            let partnerDraft = SQLPartner.Draft(
                id: UUID(),
                name: partnerData.name,
                notes: partnerData.notes,
                phoneNumber: partnerData.phoneNumber,
                relationshipType: partnerData.relationshipType,
                dateMet: partnerData.dateMet,
                avatarColor: SQLPartner.randomColorName(),
                dateAdded: Date(),
                lastEncounterDate: nil,
                isPinned: false
            )
            
            do {
                _ = try partnerService.create(partnerDraft)
            } catch {
                logger.error("Failed to import partner: \(error)")
            }
        }

        isImporting = false
        dismiss()
    }
}

// MARK: - Partner Import Data

struct PartnerImportData {
    let name: String
    let phoneNumber: String
    let notes: String
    let relationshipType: SQLRelationshipType
    let dateMet: Date?
}

#Preview {
    PartnerImportView()
}
