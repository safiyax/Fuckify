//
//  CSVImportInstructionsView.swift
//  Fuckify
//
//

import SwiftUI

struct CSVImportInstructionsView: View {
    let title: String
    let color: Color
    let format: String
    let example: String
    let notes: String
    let onSelectFile: () -> Void

    private var descriptionText: String {
        switch title {
        case "Import Partners from CSV":
            return "Select a CSV file with partner information to import."
        case "Import Encounters from CSV":
            return "Select a CSV file with encounter information to import."
        default:
            return "Select a CSV file with information to import."
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(color)

            Text(title)
                .font(.title2)
                .fontWeight(.bold)

            Text(descriptionText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("CSV Format:")
                    .font(.headline)

                Text(format)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Text("Example:")
                    .font(.headline)
                    .padding(.top, 8)

                Text(example)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)

                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            Button(action: onSelectFile) {
                Label("Select CSV File", systemImage: "doc.badge.plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(color)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    CSVImportInstructionsView(
        title: "Import Partners from CSV",
        color: .blue,
        format: "name,phoneNumber,notes,relationshipType,dateMet",
        example: "John Doe,555-0123,Met at gym,Regular,2024-01-15",
        notes: "• Name is required\n• Other fields are optional\n• relationshipType: Casual, Regular, Committed, One-Time, Other\n• dateMet: YYYY-MM-DD format",
        onSelectFile: {}
    )
    .padding()
}
