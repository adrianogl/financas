import SwiftUI

struct TransactionRow: View {
    let entry: HomeEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(legend) · \(IncomeFormat.shortDate(entry.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(sign) \(IncomeFormat.currency(entry.amount))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(entry.kind == .income ? AnyShapeStyle(Theme.positive) : AnyShapeStyle(.primary))
        }
        .padding(.vertical, 6)
    }

    private var legend: String {
        entry.kind == .income ? "Receita" : "Despesa"
    }

    private var sign: String {
        entry.kind == .income ? "+" : "−"
    }
}
