import SwiftUI

struct RecurringIncomeRow: View {
    let income: Income
    let rate: Decimal?

    var body: some View {
        HStack(spacing: 12) {
            IncomeIcon(systemImage: "arrow.trianglehead.2.clockwise", tint: income.kind.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(income.name)
                    .font(.subheadline.weight(.semibold))
                Text(IncomeFormat.rule(for: income, rate: rate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}
