import Foundation

struct ExpensePayable: Identifiable, Hashable {
    let occurrence: ExpenseOccurrence
    let part: ExpensePartValue?
    let id: String
    let title: String
    let amount: Decimal
    let dueDate: CalendarDay
    let status: ExpenseStatus

    init(occurrence: ExpenseOccurrence, part: ExpensePartValue? = nil, today: CalendarDay) {
        self.occurrence = occurrence
        self.part = part
        let occurrenceTitle = ExpenseFormat.occurrenceTitle(occurrence, today: today)
        if let part {
            id = part.id
            title = "\(occurrenceTitle) · \(part.part.name)"
            amount = part.amount
            dueDate = part.dueDate
            status = part.status
        } else {
            id = occurrence.id
            title = occurrenceTitle
            amount = occurrence.amount
            dueDate = occurrence.dueDate
            status = occurrence.status
        }
    }

    static func payables(of occurrence: ExpenseOccurrence, today: CalendarDay) -> [ExpensePayable] {
        guard !occurrence.parts.isEmpty else { return [ExpensePayable(occurrence: occurrence, today: today)] }
        return occurrence.parts.map { ExpensePayable(occurrence: occurrence, part: $0, today: today) }
    }
}
