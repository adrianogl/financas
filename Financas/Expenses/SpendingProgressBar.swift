import SwiftUI

struct SpendingProgressBar: View {
    let spending: SpendingMonth
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(.secondary.opacity(0.2))
            .frame(height: height)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(spending.isOver ? Theme.warning : Theme.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .accessibilityHidden(true)
    }

    private var fraction: CGFloat {
        guard spending.expected > 0 else { return spending.spent > 0 ? 1 : 0 }
        let ratio = NSDecimalNumber(decimal: spending.spent / spending.expected).doubleValue
        return CGFloat(min(max(ratio, 0), 1))
    }
}
