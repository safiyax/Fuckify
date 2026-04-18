import SwiftUI

/// A standard row for customization settings lists.
/// Shows an icon, a name, an optional "Built-in" badge, an optional extra badge, and a toggle.
struct CustomizationItemRow: View {
    let icon: String
    let name: String
    let isEnabled: Bool
    let isBuiltIn: Bool
    let accentColor: Color
    /// An optional extra badge label shown after the Built-in badge (e.g. field type).
    var extraBadge: String? = nil
    /// An optional extra badge background color.
    var extraBadgeColor: Color = .purple
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isEnabled ? accentColor : .gray)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundColor(isEnabled ? .primary : .secondary)

                if isBuiltIn || extraBadge != nil {
                    HStack(spacing: 4) {
                        if isBuiltIn {
                            BuiltInBadge()
                        }
                        if let badge = extraBadge {
                            Text(badge)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(extraBadgeColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .accessibilityLabel("\(name) enabled")
        }
        .padding(.vertical, isBuiltIn ? 0 : 2)
    }
}

#Preview {
    List {
        CustomizationItemRow(
            icon: "heart.fill",
            name: "Kissing",
            isEnabled: true,
            isBuiltIn: false,
            accentColor: .purple,
            onToggle: {}
        )
        CustomizationItemRow(
            icon: "shield.fill",
            name: "Condom",
            isEnabled: true,
            isBuiltIn: true,
            accentColor: .green,
            onToggle: {}
        )
        CustomizationItemRow(
            icon: "star.fill",
            name: "Partner Rating",
            isEnabled: false,
            isBuiltIn: false,
            accentColor: .accentColor,
            extraBadge: "Number",
            extraBadgeColor: .purple,
            onToggle: {}
        )
    }
}
