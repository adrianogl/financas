import Foundation

struct ExpenseOccurrence: Identifiable, Hashable {
    let expense: Expense
    let month: YearMonth
    let dueDate: CalendarDay
    let estimate: ExpenseEstimate
    let bill: ExpenseBill?
    let status: ExpenseStatus
    var parts: [ExpensePartValue] = []

    var amount: Decimal {
        bill?.paidAmount ?? bill?.billAmount ?? estimate.amount
    }

    var hasBill: Bool {
        bill?.billAmount != nil
    }

    var id: String {
        "\(expense.id)-\(month.year)-\(month.month)"
    }
}
