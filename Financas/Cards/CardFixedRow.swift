import SwiftUI

struct CardFixedRow: View {
    let charge: FixedCharge
    let nickname: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(charge.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(nickname)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if charge.isStale {
                        CardPill(text: "sem cobrança recente", color: Theme.review)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(IncomeFormat.currency(charge.amount))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.vertical, 8)
    }
}
