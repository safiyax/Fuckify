import SwiftUI

struct EntityIconRow: View {
    let entities: [(icon: String, name: String)]
    let color: Color
    let maxShown: Int
    let font: Font

    private var shownCount: Int {
        max(0, maxShown)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(entities.prefix(shownCount).enumerated()), id: \.offset) { _, entity in
                Image(systemName: entity.icon)
                    .foregroundColor(color)
                    .font(font)
                    .accessibilityLabel(entity.name)
            }

            if entities.count > shownCount {
                Text("+\(entities.count - shownCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
