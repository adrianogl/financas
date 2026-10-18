import SwiftUI

struct OverdueRow: View {
    let occurrence: IncomeOccurrence
    let today: CalendarDay
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(IncomeFormat.occurrenceTitle(occurrence))
                    .font(.subheadline.weight(.semibold))
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(IncomeFormat.currency(occurrence.expectedAmount))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if occurrence.month < today.yearMonth {
                    OverdueBadge(text: IncomeFormat.monthName(occurrence.month))
                }
            }
        }
        .padding(.vertical, 6)
        .selectedRowBackground(isSelected)
        .contentShape(.rect)
    }

    private var caption: String {
        let days = occurrence.dueDate.days(until: today)
        let label = days == 1 ? "1 dia" : "\(days) dias"
        return "\(IncomeFormat.shortDate(occurrence.dueDate)) · \(label)"
    }
}
