import Foundation

extension DueItem {
    init(expense occurrence: ExpenseOccurrence, today: CalendarDay) {
        self.init(
            id: occurrence.id,
            kind: .expense,
            title: ExpenseFormat.occurrenceTitle(occurrence, today: today),
            amount: occurrence.amount,
            dueDate: occurrence.dueDate
        )
    }
}
