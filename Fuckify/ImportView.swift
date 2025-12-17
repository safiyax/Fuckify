//
//  ImportView.swift
//  Fuckify
//
//

import SwiftUI

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingPartnerImport = false
    @State private var showingEncounterImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.top, 40)

                Text("Import Data")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Choose what you'd like to import from CSV files")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 16) {
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
                .padding(.top, 20)

                Spacer()
            }
            .navigationTitle("Import Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingPartnerImport) {
                PartnerImportView()
            }
            .sheet(isPresented: $showingEncounterImport) {
                EncounterImportView()
            }
        }
    }
}

#Preview {
    ImportView()
}
