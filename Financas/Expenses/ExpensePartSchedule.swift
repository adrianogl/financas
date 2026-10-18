import Foundation

enum ExpensePartSchedule {
    static func term(for part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpensePartTerm? {
        snapshot.partTerms
            .filter { $0.partID == part.id && $0.validFrom <= month }
            .max { $0.validFrom < $1.validFrom }
    }

    static func activeParts(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> [ExpensePart] {
        snapshot.parts
            .filter { $0.expenseID == expense.id && term(for: $0, in: month, snapshot: snapshot)?.isActive == true }
            .sorted { $0.position < $1.position }
    }

    static func estimate(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpensePartValue? {
        guard let term = term(for: part, in: month, snapshot: snapshot) else { return nil }
        guard !term.isFixed else {
            return ExpensePartValue(part: part, amount: term.amount, origin: .fixed, isFixed: true)
        }
        let paid = snapshot.bills
            .filter { $0.expenseID == part.expenseID && $0.month < month && $0.month >= term.averageFrom }
            .compactMap { bill in bill.paidParts?[part.id].map { (month: bill.month, amount: $0) } }
        guard let average = ExpenseSchedule.average(of: paid) else {
            return ExpensePartValue(part: part, amount: term.amount, origin: .estimated, isFixed: false)
        }
        return ExpensePartValue(part: part, amount: average.amount, origin: .average(months: average.months), isFixed: false)
    }

    static func values(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> [ExpensePartValue] {
        let bill = bill(of: expense.id, in: month, snapshot: snapshot)
        return activeParts(of: expense, in: month, snapshot: snapshot).compactMap { part in
            let isFixed = term(for: part, in: month, snapshot: snapshot)?.isFixed ?? false
            if let amount = bill?.paidParts?[part.id] {
                return ExpensePartValue(part: part, amount: amount, origin: .paid, isFixed: isFixed)
            }
            if let amount = bill?.billParts?[part.id] {
                return ExpensePartValue(part: part, amount: amount, origin: .bill, isFixed: isFixed)
            }
            return estimate(of: part, in: month, snapshot: snapshot)
        }
    }

    static func change(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> Decimal? {
        guard let current = registered(part, in: month, snapshot: snapshot),
              let previous = registered(part, in: month.previous, snapshot: snapshot) else { return nil }
        return current - previous
    }

    private static func registered(_ part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> Decimal? {
        let bill = bill(of: part.expenseID, in: month, snapshot: snapshot)
        return bill?.paidParts?[part.id] ?? bill?.billParts?[part.id]
    }

    private static func bill(of expenseID: UUID, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpenseBill? {
        snapshot.bills.first { $0.expenseID == expenseID && $0.month == month }
    }
}
