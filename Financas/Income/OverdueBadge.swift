import SwiftUI

struct OverdueBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.warning)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(Theme.warning.opacity(0.12), in: .capsule)
    }
}
