import SwiftUI

struct TransactionRow: View {
    let transaction: SampleTransaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: transaction.systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(tint, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(transaction.category) · \(transaction.dateLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(amountText)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(transaction.isIncome ? Theme.positive : .primary)
        }
        .padding(.vertical, 6)
    }

    private var tint: Color {
        Theme.categoryTints.indices.contains(transaction.tintIndex) ? Theme.categoryTints[transaction.tintIndex] : Theme.positive
    }

    private var amountText: String {
        let value = abs(transaction.amount).formatted(.currency(code: HomeConstants.currencyCode))
        return transaction.isIncome ? "+ \(value)" : value
    }
}
