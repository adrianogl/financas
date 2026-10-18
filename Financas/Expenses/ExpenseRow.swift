import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    let term: ExpenseTerm?
    let estimate: ExpenseEstimate?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.subheadline.weight(.semibold))
                if let term, let estimate {
                    Text(ExpenseFormat.rule(term, estimate: estimate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let estimate {
                Text(IncomeFormat.currency(estimate.amount))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }
}
