//
//  ImportView.swift
//  Fuckify
//
//

import SwiftUI
import SwiftData

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allPartners: [Partner]
    @Query private var allEncounters: [Encounter]

    @State private var showingPartnerImport = false
    @State private var showingEncounterImport = false
    @State private var partnerExportURL: URL?
    @State private var encounterExportURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Import Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                                .font(.title2)
                                .foregroundColor(.blue)

                            Text("Import")
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            Button(action: { showingPartnerImport = true }) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                        .frame(width: 50)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Import Partners")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text("Add partners from a CSV file")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)

                            Button(action: { showingEncounterImport = true }) {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .font(.title2)
                                        .foregroundColor(.pink)
                                        .frame(width: 50)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Import Encounters")
                                            .font(.headline)
                                            .foregroundColor(.primary)

                                        Text("Add encounters from a CSV file")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    }

                    // Export Section
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.green)

                            Text("Export")
                                .font(.title2)
                                .fontWeight(.bold)

                            Spacer()
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            if let url = partnerExportURL {
                                ShareLink(item: url) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                            .frame(width: 50)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Export Partners")
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text("\(allPartners.count) partners")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: { exportPartners() }) {
                                    HStack {
                                        Image(systemName: "person.2.fill")
                                            .font(.title2)
                                            .foregroundColor(.blue)
                                            .frame(width: 50)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Export Partners")
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text("\(allPartners.count) partners")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(allPartners.isEmpty)
                                .opacity(allPartners.isEmpty ? 0.5 : 1.0)
                            }

                            if let url = encounterExportURL {
                                ShareLink(item: url) {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .font(.title2)
                                            .foregroundColor(.pink)
                                            .frame(width: 50)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Export Encounters")
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text("\(allEncounters.count) encounters")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button(action: { exportEncounters() }) {
                                    HStack {
                                        Image(systemName: "heart.fill")
                                            .font(.title2)
                                            .foregroundColor(.pink)
                                            .frame(width: 50)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Export Encounters")
                                                .font(.headline)
                                                .foregroundColor(.primary)

                                            Text("\(allEncounters.count) encounters")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
                                .disabled(allEncounters.isEmpty)
                                .opacity(allEncounters.isEmpty ? 0.5 : 1.0)
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.vertical, 20)
            }
            .navigationTitle("Data Management")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPartnerImport) {
                PartnerImportView()
            }
            .sheet(isPresented: $showingEncounterImport) {
                EncounterImportView()
            }
            .onAppear {
                // Pre-generate export files so ShareLink has them ready
                if !allPartners.isEmpty && partnerExportURL == nil {
                    exportPartners()
                }
                if !allEncounters.isEmpty && encounterExportURL == nil {
                    exportEncounters()
                }
            }
        }
    }

    private func exportPartners() {
        var csvString = "name,phoneNumber,notes,isOnPrep,relationshipType,dateMet\n"

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        
        let created = Date()
        
        for partner in allPartners {
            let name = escapeCSVField(partner.name)
            let phoneNumber = escapeCSVField(partner.phoneNumber)
            let notes = escapeCSVField(partner.notes)
            let isOnPrep = partner.isOnPrep ? "true" : "false"
            let relationshipType = partner.relationshipType.rawValue
            let dateMet = partner.dateMet != nil ? dateFormatter.string(from: partner.dateMet!) : ""

            csvString += "\(name),\(phoneNumber),\(notes),\(isOnPrep),\(relationshipType),\(dateMet)\n"
        }
        
        print("csv generation time: \(Date().timeIntervalSince(created))")

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("partners_export.csv")

        do {
            let created = Date()
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("csv write time: \(Date().timeIntervalSince(created))")
            partnerExportURL = fileURL
        } catch {
            print("Failed to write CSV: \(error)")
        }
    }

    private func exportEncounters() {
        var csvString = "date,duration,activities,protectionMethods,location,notes,rating,reachedOrgasm,partnerNames\n"

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]

        for encounter in allEncounters {
            let date = dateFormatter.string(from: encounter.date)
            let duration = String(Int(encounter.duration / 60)) // Convert to minutes
            let activities = escapeCSVField(encounter.activities.map { $0.rawValue }.joined(separator: ", "))
            let protectionMethods = escapeCSVField(encounter.protectionMethods.map { $0.rawValue }.joined(separator: ", "))
            let location = escapeCSVField(encounter.location)
            let notes = escapeCSVField(encounter.notes)
            let rating = String(encounter.rating)
            let reachedOrgasm = encounter.reachedOrgasm ? "true" : "false"
            let partnerNames = escapeCSVField(encounter.partners?.map { $0.name }.joined(separator: ", ") ?? "")

            csvString += "\(date),\(duration),\(activities),\(protectionMethods),\(location),\(notes),\(rating),\(reachedOrgasm),\(partnerNames)\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("encounters_export.csv")

        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            encounterExportURL = fileURL
        } catch {
            print("Failed to write CSV: \(error)")
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}

#Preview {
    ImportView()
}
