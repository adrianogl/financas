import SwiftUI

struct DetailAmountBox: View {
    let title: String
    let value: String
    let caption: String
    var valueColor: Color = .primary
    var tint: Color = .secondary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(DetailConstants.boxTintOpacity), in: .rect(cornerRadius: DetailConstants.boxCornerRadius))
    }
}
