import SwiftUI

struct ExpenseOccurrenceRow: View {
    let occurrence: ExpenseOccurrence
    let today: CalendarDay
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ExpenseFormat.occurrenceTitle(occurrence, today: today))
                    .font(.subheadline.weight(.semibold))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(occurrence.status == .paid ? Theme.positive : .primary)
                badge
            }
        }
        .padding(.vertical, 6)
        .selectedRowBackground(isSelected)
        .contentShape(.rect)
    }

    @ViewBuilder
    private var badge: some View {
        switch occurrence.status {
        case .overdue:
            OverdueBadge(text: "atrasada")
        case .pending:
            if occurrence.expense.isFixed {
                EmptyView()
            } else if occurrence.hasBill {
                ExpenseBadge(text: "conta lançada", tint: ExpenseBadgeConstants.billTint)
            } else {
                ExpenseBadge(text: "estimada", tint: ExpenseBadgeConstants.estimateTint)
            }
        case .paid:
            EmptyView()
        }
    }

    private var caption: String {
        guard occurrence.status == .paid, let paidOn = occurrence.bill?.paidOn else {
            return IncomeFormat.shortDate(occurrence.dueDate)
        }
        return "pago em \(IncomeFormat.shortDate(paidOn))"
    }

    private var amountText: String {
        let amount = IncomeFormat.currency(occurrence.amount)
        return occurrence.status == .paid ? "− \(amount)" : amount
    }
}
