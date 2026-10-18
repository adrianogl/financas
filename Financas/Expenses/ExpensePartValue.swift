import Foundation

struct ExpensePartValue: Hashable, Identifiable {
    let part: ExpensePart
    let month: YearMonth
    let amount: Decimal
    let origin: ExpensePartOrigin
    let isFixed: Bool
    let dueDate: CalendarDay
    let bill: ExpensePartBill?
    let status: ExpenseStatus

    var id: String {
        "\(part.id)-\(month.year)-\(month.month)"
    }
}
