//
//  EncounterImportView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct EncounterImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allPartners: [Partner]

    @State private var showingFilePicker = false
    @State private var importedEncounters: [EncounterImportData] = []
    @State private var showingPreview = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if importedEncounters.isEmpty {
                    // Instructions
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.pink)

                            Text("Import Encounters from CSV")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Select a CSV file with encounter information to import.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("CSV Format:")
                                    .font(.headline)

                                Text("date,duration,activities,protectionMethods,location,notes,rating,reachedOrgasm,partnerNames")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                Text("Example:")
                                    .font(.headline)
                                    .padding(.top, 8)

                                Text("2024-01-15,30,\"Oral, Kissing\",Condom,Home,Great time,5,true,John Doe")
                                    .font(.system(.caption, design: .monospaced))
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                Text("• Date: YYYY-MM-DD format (required)\n• Duration: minutes (optional)\n• Activities: comma-separated in quotes (Oral, Vaginal, Anal, Manual, Kissing, Other)\n• Protection: comma-separated in quotes (Condom, PrEP, Pull Out, None, Other)\n• Location: text (optional)\n• Notes: text (optional)\n• Rating: 1-5 (optional)\n• Orgasm: true or false (optional)\n• Partners: comma-separated names in quotes matching existing partners")
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
                                    .background(Color.pink)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                } else {
                    // Preview imported data
                    List {
                        Section {
                            Text("Found \(importedEncounters.count) encounter(s) to import")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        ForEach(Array(importedEncounters.enumerated()), id: \.offset) { index, encounter in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(encounter.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)

                                if !encounter.partnerNames.isEmpty {
                                    Text("Partners: \(encounter.partnerNames.joined(separator: ", "))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    if !encounter.activities.isEmpty {
                                        Text("\(encounter.activities.count) activities")
                                            .font(.caption)
                                            .foregroundColor(.purple)
                                    }

                                    if encounter.rating > 0 {
                                        HStack(spacing: 2) {
                                            ForEach(1...encounter.rating, id: \.self) { _ in
                                                Image(systemName: "star.fill")
                                                    .font(.caption2)
                                                    .foregroundColor(.yellow)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Import Encounters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if !importedEncounters.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Import") {
                            importEncounters()
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
            print(errorMessage)
            showingError = true
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }

        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))

        return fields
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

            var encounters: [EncounterImportData] = []

            for (index, line) in lines.enumerated() {
                if index == 0 { continue } // Skip header

                let components = parseCSVLine(line)

                guard !components.isEmpty, !components[0].isEmpty else { continue }

                // Parse date (required)
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
                guard let date = formatter.date(from: components[0]) else {
                    print("Skipping row \(index): invalid date format")
                    continue
                }

                // Parse duration (optional, in minutes)
                var duration: TimeInterval = 0
                if components.count > 1, !components[1].isEmpty, let minutes = Int(components[1]) {
                    duration = TimeInterval(minutes * 60)
                }

                // Parse activities (optional, comma-separated)
                var activities: [ActivityType] = []
                if components.count > 2, !components[2].isEmpty {
                    let activityNames = components[2].components(separatedBy: ",")
                    activities = activityNames.compactMap { ActivityType(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
                }

                // Parse protection methods (optional, comma-separated)
                var protectionMethods: [ProtectionMethod] = []
                if components.count > 3, !components[3].isEmpty {
                    let methodNames = components[3].components(separatedBy: ",")
                    protectionMethods = methodNames.compactMap { ProtectionMethod(rawValue: $0.trimmingCharacters(in: .whitespaces)) }
                }

                // Parse location (optional)
                let location = components.count > 4 ? components[4] : ""

                // Parse notes (optional)
                let notes = components.count > 5 ? components[5] : ""

                // Parse rating (optional, 1-5)
                var rating = 0
                if components.count > 6, !components[6].isEmpty, let ratingValue = Int(components[6]) {
                    rating = min(max(ratingValue, 0), 5)
                }

                // Parse reachedOrgasm (optional)
                var reachedOrgasm = false
                if components.count > 7, !components[7].isEmpty {
                    reachedOrgasm = components[7].lowercased() == "true"
                }

                // Parse partner names (optional, comma-separated)
                var partnerNames: [String] = []
                if components.count > 8, !components[8].isEmpty {
                    partnerNames = components[8].components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }

                encounters.append(EncounterImportData(
                    date: date,
                    duration: duration,
                    activities: activities,
                    protectionMethods: protectionMethods,
                    location: location,
                    notes: notes,
                    rating: rating,
                    reachedOrgasm: reachedOrgasm,
                    partnerNames: partnerNames
                ))
            }

            if encounters.isEmpty {
                errorMessage = "No valid encounters found in CSV file"
                showingError = true
            } else {
                importedEncounters = encounters
            }

        } catch {
            errorMessage = "Failed to read CSV file: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func importEncounters() {
        isImporting = true

        for encounterData in importedEncounters {
            // Match partner names to existing partners, or create new ones
            var matchedPartners: [Partner] = []
            for partnerName in encounterData.partnerNames {
                if let partner = allPartners.first(where: { $0.name == partnerName }) {
                    // Partner exists, use it
                    matchedPartners.append(partner)
                } else {
                    // Partner doesn't exist, create a new one
                    let newPartner = Partner(name: partnerName)
                    modelContext.insert(newPartner)
                    matchedPartners.append(newPartner)
                }
            }

            let encounter = Encounter(
                date: encounterData.date,
                duration: encounterData.duration,
                activities: encounterData.activities,
                protectionMethods: encounterData.protectionMethods,
                location: encounterData.location,
                notes: encounterData.notes,
                rating: encounterData.rating,
                reachedOrgasm: encounterData.reachedOrgasm,
                partners: matchedPartners
            )
            modelContext.insert(encounter)

            // Update lastEncounterDate for matched partners
            for partner in matchedPartners {
                if partner.lastEncounterDate == nil || partner.lastEncounterDate! < encounterData.date {
                    partner.lastEncounterDate = encounterData.date
                }
            }
        }

        isImporting = false
        dismiss()
    }
}

// MARK: - Encounter Import Data

struct EncounterImportData {
    let date: Date
    let duration: TimeInterval
    let activities: [ActivityType]
    let protectionMethods: [ProtectionMethod]
    let location: String
    let notes: String
    let rating: Int
    let reachedOrgasm: Bool
    let partnerNames: [String]
}

#Preview {
    EncounterImportView()
        .modelContainer(for: [Encounter.self, Partner.self], inMemory: true)
}
