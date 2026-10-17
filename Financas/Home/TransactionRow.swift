import SwiftUI

struct TransactionRow: View {
    let entry: HomeEntry

    var body: some View {
        HStack(spacing: 12) {
            IncomeIcon(systemImage: entry.kind.systemImage, tint: Theme.positive)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                Text("Receita · \(IncomeFormat.shortDate(entry.receivedOn))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("+ \(IncomeFormat.currency(entry.amount))")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.positive)
        }
        .padding(.vertical, 6)
    }
}
