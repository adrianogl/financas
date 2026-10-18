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

    static func estimate(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> (amount: Decimal, origin: ExpensePartOrigin)? {
        guard let term = term(for: part, in: month, snapshot: snapshot) else { return nil }
        guard !term.isFixed else { return (term.amount, .fixed) }
        let paid = snapshot.partBills
            .filter { $0.partID == part.id && $0.month < month && $0.month >= term.averageFrom }
            .compactMap { bill in bill.paidAmount.map { (month: bill.month, amount: $0) } }
        guard let average = ExpenseSchedule.average(of: paid) else { return (term.amount, .estimated) }
        return (average.amount, .average(months: average.months))
    }

    static func values(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [ExpensePartValue] {
        let expenseDay = ExpenseSchedule.term(for: expense, in: month, snapshot: snapshot)?.dayOfMonth ?? 1
        return activeParts(of: expense, in: month, snapshot: snapshot).compactMap { part in
            guard let term = term(for: part, in: month, snapshot: snapshot),
                  let estimate = estimate(of: part, in: month, snapshot: snapshot) else { return nil }
            let bill = bill(of: part, in: month, snapshot: snapshot)
            let (amount, origin): (Decimal, ExpensePartOrigin) = if let paid = bill?.paidAmount {
                (paid, .paid)
            } else if let launched = bill?.billAmount {
                (launched, .bill)
            } else {
                estimate
            }
            let dueDate = bill?.billDueDate ?? BusinessCalendar.businessDayOnOrAfter(month.day(term.dayOfMonth ?? expenseDay))
            let status: ExpenseStatus = bill?.paidAmount != nil ? .paid : (dueDate < today ? .overdue : .pending)
            return ExpensePartValue(
                part: part,
                month: month,
                amount: amount,
                origin: origin,
                isFixed: term.isFixed,
                dueDate: dueDate,
                bill: bill,
                status: status
            )
        }
    }

    static func change(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> Decimal? {
        guard let current = registered(part, in: month, snapshot: snapshot),
              let previous = registered(part, in: month.previous, snapshot: snapshot) else { return nil }
        return current - previous
    }

    private static func registered(_ part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> Decimal? {
        let bill = bill(of: part, in: month, snapshot: snapshot)
        return bill?.paidAmount ?? bill?.billAmount
    }

    private static func bill(of part: ExpensePart, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpensePartBill? {
        snapshot.partBills.first { $0.partID == part.id && $0.month == month }
    }
}
