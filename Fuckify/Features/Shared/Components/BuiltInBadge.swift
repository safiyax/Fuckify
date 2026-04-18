import SwiftUI

/// A small pill badge indicating a built-in (non-deletable) item.
struct BuiltInBadge: View {
    var body: some View {
        Text("Built-in")
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(4)
    }
}

#Preview {
    BuiltInBadge()
        .padding()
}
