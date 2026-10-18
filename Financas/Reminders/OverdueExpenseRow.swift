import SwiftUI

struct OverdueExpenseRow: View {
    let payable: ExpensePayable
    let today: CalendarDay
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(payable.title)
                    .font(.subheadline.weight(.semibold))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(IncomeFormat.currency(payable.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if payable.occurrence.month < today.yearMonth {
                    OverdueBadge(text: IncomeFormat.monthName(payable.occurrence.month))
                }
            }
        }
        .padding(.vertical, 6)
        .selectedRowBackground(isSelected)
        .contentShape(.rect)
    }

    private var caption: String {
        let days = payable.dueDate.days(until: today)
        let label = days == 1 ? "1 dia" : "\(days) dias"
        return "\(IncomeFormat.shortDate(payable.dueDate)) · \(label)"
    }
}
