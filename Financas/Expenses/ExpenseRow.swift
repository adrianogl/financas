import SwiftUI

struct ExpenseRow: View {
    let expense: Expense
    let term: ExpenseTerm?
    let estimate: ExpenseEstimate?
    let partCount: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.name)
                    .font(.subheadline.weight(.semibold))
                if let rule {
                    Text(rule)
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

    private var rule: String? {
        guard let term, let estimate else { return nil }
        guard expense.kind == .bill else { return ExpenseFormat.spendingRule(term.estimatedAmount) }
        return ExpenseFormat.rule(term, estimate: estimate, partCount: partCount)
    }
}
