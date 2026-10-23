import SwiftUI

struct CardEndingRow: View {
    let plan: InstallmentPlan
    let nickname: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text("\(nickname) · \(CardFormat.endingText(plan))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 3) {
                Text(IncomeFormat.currency(plan.installmentAmount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                CardPill(text: CardFormat.releasesText(plan), color: Theme.positive)
            }
        }
        .padding(.vertical, 8)
    }
}
