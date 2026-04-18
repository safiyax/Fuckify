import SwiftUI

/// A tappable row that shows the currently selected SF Symbol and opens the picker.
/// Used in customization item form views (activities, protection methods, positions).
struct IconPickerRow: View {
    @Binding var selectedIcon: String
    let accentColor: Color
    let isDisabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            if !isDisabled {
                onTap()
            }
        } label: {
            HStack {
                Image(systemName: selectedIcon)
                    .foregroundColor(accentColor)
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(accentColor.opacity(0.1))
                    .cornerRadius(8)

                Text("Choose Icon")
                    .foregroundColor(isDisabled ? .secondary : .primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .disabled(isDisabled)
    }
}

#Preview {
    Form {
        Section("Icon") {
            IconPickerRow(
                selectedIcon: .constant("heart.fill"),
                accentColor: .purple,
                isDisabled: false,
                onTap: {}
            )
        }

        Section("Icon (disabled)") {
            IconPickerRow(
                selectedIcon: .constant("shield.fill"),
                accentColor: .green,
                isDisabled: true,
                onTap: {}
            )
        }
    }
}
