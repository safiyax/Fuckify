import SwiftUI

/// A standard icon + label row used in Settings lists.
/// Use inside a `NavigationLink` label or standalone `Button` label.
struct SettingsRow: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(label)
        }
    }
}

#Preview {
    List {
        NavigationLink(destination: EmptyView()) {
            SettingsRow(icon: "heart.fill", color: .pink, label: "Support the App")
        }
        NavigationLink(destination: EmptyView()) {
            SettingsRow(icon: "shield.fill", color: .green, label: "Protection Methods")
        }
    }
}
