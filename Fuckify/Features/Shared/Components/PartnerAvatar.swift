import SwiftUI

/// A colored circle displaying a partner's initials, used wherever a partner is represented visually.
/// Font size scales automatically with the circle size.
struct PartnerAvatar: View {
    let color: Color
    let initials: String
    let size: CGFloat

    init(color: Color, initials: String, size: CGFloat = 50) {
        self.color = color
        self.initials = initials
        self.size = size
    }

    private var fontSize: CGFloat {
        switch size {
        case ..<30: return 10
        case 30..<45: return 14
        case 45..<60: return 18
        case 60..<80: return 24
        case 80..<100: return 32
        default: return size * 0.38
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        PartnerAvatar(color: .blue, initials: "AB", size: 32)
        PartnerAvatar(color: .pink, initials: "CD", size: 50)
        PartnerAvatar(color: .purple, initials: "EF", size: 96)
        PartnerAvatar(color: .green, initials: "GH", size: 100)
    }
    .padding()
}
