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
        guard parts.isEmpty else { return parts.map(\.amount).reduce(0, +) }
        return bill?.paidAmount ?? bill?.billAmount ?? estimate.amount
    }

    var remaining: Decimal {
        guard parts.isEmpty else { return parts.filter { $0.status != .paid }.map(\.amount).reduce(0, +) }
        return status == .paid ? 0 : amount
    }

    var isPartiallyPaid: Bool {
        parts.contains { $0.status == .paid } && parts.contains { $0.status != .paid }
    }

    var paidOn: CalendarDay? {
        guard parts.isEmpty else { return status == .paid ? parts.compactMap(\.bill?.paidOn).max() : nil }
        return bill?.paidAmount != nil ? bill?.paidOn : nil
    }

    var hasBill: Bool {
        guard parts.isEmpty else { return parts.contains { $0.bill?.billAmount != nil } }
        return bill?.billAmount != nil
    }

    var amountDue: Decimal {
        isPartiallyPaid ? remaining : amount
    }

    var isFixed: Bool {
        parts.isEmpty ? expense.isFixed : parts.allSatisfy(\.isFixed)
    }

    var badge: ExpenseOccurrenceBadge? {
        switch status {
        case .overdue:
            return .overdue
        case .pending where isPartiallyPaid:
            return .partiallyPaid
        case .pending:
            if isFixed { return nil }
            return hasBill ? .billLaunched : .estimated
        case .paid:
            return nil
        }
    }

    var id: String {
        "\(expense.id)-\(month.year)-\(month.month)"
    }
}
