import SwiftUI

struct RecurrenceReviewBanner: View {
    let count: Int
    let names: [String]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("\(count)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(Theme.review)
                    .frame(width: CardConstants.reviewDotSize, height: CardConstants.reviewDotSize)
                    .background(Theme.reviewTint.opacity(CardConstants.reviewDotOpacity), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(CardFormat.reviewTitle(count))
                        .font(.subheadline.weight(.semibold))
                    Text(names.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 2) {
                    Text("Revisar")
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Theme.reviewTint.opacity(CardConstants.reviewBorderOpacity))
        }
    }
}
