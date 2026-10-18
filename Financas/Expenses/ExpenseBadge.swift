import SwiftUI

struct ExpenseBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(tint.opacity(ExpenseBadgeConstants.backgroundOpacity), in: .capsule)
    }
}
