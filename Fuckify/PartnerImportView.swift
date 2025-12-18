//
//  PartnerImportView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PartnerImportView: View {
    @Environment(\.modelContext) private var modelContext
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
                    // Instructions
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Import Partners from CSV")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Select a CSV file with partner information to import.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("CSV Format:")
                                .font(.headline)

                            Text("name,phoneNumber,notes,isOnPrep,relationshipType,dateMet")
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            Text("Example:")
                                .font(.headline)
                                .padding(.top, 8)

                            Text("John Doe,555-0123,Met at gym,true,Regular,2024-01-15")
                                .font(.system(.caption, design: .monospaced))
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)

                            Text("• Name is required\n• Other fields are optional\n• isOnPrep: true or false\n• relationshipType: Casual, Regular, Committed, One-Time, Other\n• dateMet: YYYY-MM-DD format")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        Button(action: { showingFilePicker = true }) {
                            Label("Select CSV File", systemImage: "doc.badge.plus")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
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

                                HStack {
                                    Text(partner.relationshipType.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    if partner.isOnPrep {
                                        Text("• PrEP")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
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
                let isOnPrep = components.count > 3 ? (components[3].lowercased() == "true") : false

                let relationshipType: RelationshipType
                if components.count > 4 {
                    relationshipType = RelationshipType(rawValue: components[4]) ?? .casual
                } else {
                    relationshipType = .casual
                }

                var dateMet: Date? = nil
                if components.count > 5, !components[5].isEmpty {
                    dateMet = parseDate(components[5])
                }

                partners.append(PartnerImportData(
                    name: name,
                    phoneNumber: phoneNumber,
                    notes: notes,
                    isOnPrep: isOnPrep,
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
        // Use DateFormatter with local timezone to avoid date shifting
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: dateString)
    }

    private func importPartners() {
        isImporting = true

        for partnerData in importedPartners {
            let partner = Partner(
                name: partnerData.name,
                notes: partnerData.notes,
                phoneNumber: partnerData.phoneNumber,
                isOnPrep: partnerData.isOnPrep,
                relationshipType: partnerData.relationshipType,
                dateMet: partnerData.dateMet
            )
            modelContext.insert(partner)
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
    let isOnPrep: Bool
    let relationshipType: RelationshipType
    let dateMet: Date?
}

#Preview {
    PartnerImportView()
        .modelContainer(for: Partner.self, inMemory: true)
}
