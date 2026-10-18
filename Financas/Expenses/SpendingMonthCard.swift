import SwiftUI

struct SpendingMonthCard: View {
    let spending: SpendingMonth
    let today: CalendarDay

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Gasto em \(IncomeFormat.monthName(spending.month))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(IncomeFormat.currency(spending.spent))
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(spending.isOver ? Theme.warning : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("de \(IncomeFormat.currency(spending.expected))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            SpendingProgressBar(spending: spending, height: ExpenseConstants.spendingCardBarHeight)
                .padding(.top, 2)
            Text(ExpenseFormat.spendingCaption(spending, today: today))
                .font(.caption.weight(spending.isOver ? .semibold : .regular))
                .foregroundStyle(spending.isOver ? Theme.warning : .secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}
