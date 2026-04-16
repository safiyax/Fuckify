//
//  RatingSection.swift
//  Fuckify
//
//  Reusable rating section for encounter forms
//

import SwiftUI

struct RatingSection: View {
    @Binding var rating: Int

    var body: some View {
        Section("Experience") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Button(action: { rating = star }) {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .yellow : .gray)
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(star) star\(star > 1 ? "s" : "")")
                        .accessibilityAddTraits(rating == star ? [.isSelected] : [])
                        .accessibilityHint("Double tap to rate this encounter")
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    Form {
        RatingSection(rating: .constant(4))
    }
}
