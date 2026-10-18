import SwiftUI

struct SpendingRow: View {
    let spending: SpendingMonth
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(spending.expense.name)
                    .font(.subheadline.weight(.semibold))
                Text("gasto do mês · \(ExpenseFormat.entryCount(spending.entries.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SpendingProgressBar(spending: spending, height: ExpenseConstants.spendingRowBarHeight)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 3) {
                Text(IncomeFormat.currency(spending.spent))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(spending.isOver ? Theme.warning : .primary)
                Text("de \(IncomeFormat.currency(spending.expected))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
        .selectedRowBackground(isSelected)
        .contentShape(.rect)
    }
}
