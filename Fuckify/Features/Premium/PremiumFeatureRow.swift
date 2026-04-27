//
//  PremiumFeatureRow.swift
//  Fuckify
//

import SwiftUI

struct PremiumFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    var description: String? = nil

    var body: some View {
        HStack(alignment: description != nil ? .top : .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 28, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}
