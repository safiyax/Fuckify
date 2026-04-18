import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let actionLabel: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let actionLabel, let action {
                Button(actionLabel, action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "cross.case",
        iconColor: .blue.opacity(0.5),
        title: "No tests logged yet",
        description: "Log your STI tests to track your sexual health history.",
        actionLabel: "Log First Test",
        action: {}
    )
    .padding()
}
