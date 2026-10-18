import SwiftUI

struct HomePillButton: View {
    let title: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(tint.opacity(HomeConstants.pillOpacity), in: .capsule)
                .fixedSize()
        }
        .buttonStyle(.plain)
    }
}
