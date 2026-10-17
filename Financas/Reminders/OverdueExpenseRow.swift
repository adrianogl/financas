import SwiftUI

struct OverdueExpenseRow: View {
    let occurrence: ExpenseOccurrence
    let today: CalendarDay

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
                Text(IncomeFormat.currency(occurrence.amount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if occurrence.month < today.yearMonth {
                    OverdueBadge(text: IncomeFormat.monthName(occurrence.month))
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    private var caption: String {
        let days = occurrence.dueDate.days(until: today)
        let label = days == 1 ? "1 dia" : "\(days) dias"
        return "\(IncomeFormat.shortDate(occurrence.dueDate)) · \(label)"
    }
}
