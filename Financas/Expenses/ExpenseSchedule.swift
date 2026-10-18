import Foundation

enum ExpenseSchedule {
    static func term(for expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpenseTerm? {
        let own = snapshot.terms.filter { $0.expenseID == expense.id }
        return own.filter { $0.validFrom <= month }.max { $0.validFrom < $1.validFrom }
            ?? own.min { $0.validFrom < $1.validFrom }
    }

    static func estimate(for expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot) -> ExpenseEstimate? {
        guard let term = term(for: expense, in: month, snapshot: snapshot) else { return nil }
        let parts = ExpensePartSchedule.activeParts(of: expense, in: month, snapshot: snapshot)
        guard parts.isEmpty else {
            let amounts = parts.compactMap { ExpensePartSchedule.estimate(of: $0, in: month, snapshot: snapshot)?.amount }
            return .parts(amounts.reduce(0, +))
        }
        guard !expense.isFixed else { return .fixed(term.estimatedAmount) }
        let paid = snapshot.bills
            .filter { $0.expenseID == expense.id && $0.month < month && $0.month >= term.averageFrom }
            .compactMap { bill in bill.paidAmount.map { (month: bill.month, amount: $0) } }
        guard let average = average(of: paid) else { return .manual(term.estimatedAmount) }
        return .average(amount: average.amount, months: average.months)
    }

    static func average(of paid: [(month: YearMonth, amount: Decimal)]) -> (amount: Decimal, months: [YearMonth])? {
        let recent = paid.sorted { $0.month > $1.month }.prefix(3)
        guard recent.count == 3 else { return nil }
        var average = recent.map(\.amount).reduce(0, +) / 3
        var rounded = Decimal()
        NSDecimalRound(&rounded, &average, 2, .plain)
        return (rounded, recent.map(\.month).sorted())
    }

    static func occurrence(of expense: Expense, in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> ExpenseOccurrence? {
        guard isActive(expense, in: month),
              let term = term(for: expense, in: month, snapshot: snapshot),
              let estimate = estimate(for: expense, in: month, snapshot: snapshot) else { return nil }
        let bill = snapshot.bills.first { $0.expenseID == expense.id && $0.month == month }
        let dueDate = bill?.billDueDate ?? BusinessCalendar.businessDayOnOrAfter(month.day(term.dayOfMonth))
        let status: ExpenseStatus = bill?.paidAmount != nil ? .paid : (dueDate < today ? .overdue : .pending)
        return ExpenseOccurrence(
            expense: expense,
            month: month,
            dueDate: dueDate,
            estimate: estimate,
            bill: bill,
            status: status,
            parts: ExpensePartSchedule.values(of: expense, in: month, snapshot: snapshot)
        )
    }

    static func occurrences(in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [ExpenseOccurrence] {
        bills(in: snapshot)
            .compactMap { occurrence(of: $0, in: month, snapshot: snapshot, today: today) }
            .sorted(by: ordered)
    }

    static func overdue(before month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [ExpenseOccurrence] {
        (earlier(than: month, snapshot: snapshot, today: today) + early(in: month, snapshot: snapshot, today: today))
            .filter { $0.status == .overdue }
            .sorted(by: ordered)
    }

    static func carried(into month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [ExpenseOccurrence] {
        let late = overdue(before: month, snapshot: snapshot, today: today)
        let dueLater = earlier(than: month, snapshot: snapshot, today: today)
            .filter { $0.status == .pending && $0.dueDate.yearMonth >= month }
        let dueThisMonth = early(in: month, snapshot: snapshot, today: today).filter { $0.status == .pending }
        return (late + dueLater + dueThisMonth).sorted(by: ordered)
    }

    static func summary(for month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> ExpenseMonthSummary {
        let own = occurrences(in: month, snapshot: snapshot, today: today)
        let carried = month == today.yearMonth ? carried(into: month, snapshot: snapshot, today: today) : []
        let open = (own + carried).filter { $0.status != .paid }
        let paid = own.compactMap { $0.bill?.paidAmount }.reduce(0, +)
        let remaining = open.map(\.amount).reduce(0, +)
        let upcoming = (own + carried + occurrences(in: month.next, snapshot: snapshot, today: today))
            .filter { $0.status == .pending && $0.dueDate >= today }
            .sorted(by: ordered)

        return ExpenseMonthSummary(
            paid: paid,
            remaining: remaining,
            expected: paid + remaining,
            overdueCount: open.filter { $0.status == .overdue }.count,
            next: upcoming.first
        )
    }

    private static func earlier(than month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [ExpenseOccurrence] {
        bills(in: snapshot).flatMap { expense in
            months(of: expense, before: month).compactMap { occurrence(of: expense, in: $0, snapshot: snapshot, today: today) }
        }
    }

    private static func early(in month: YearMonth, snapshot: ExpenseSnapshot, today: CalendarDay) -> [ExpenseOccurrence] {
        occurrences(in: month.next, snapshot: snapshot, today: today).filter { $0.dueDate.yearMonth <= month }
    }

    private static func bills(in snapshot: ExpenseSnapshot) -> [Expense] {
        snapshot.expenses.filter { $0.kind == .bill }
    }

    private static func isActive(_ expense: Expense, in month: YearMonth) -> Bool {
        guard expense.startMonth <= month else { return false }
        return expense.endMonth.map { month <= $0 } ?? true
    }

    private static func months(of expense: Expense, before month: YearMonth) -> [YearMonth] {
        let last = min(month.previous, expense.endMonth ?? month.previous)
        return YearMonth.range(from: expense.startMonth, through: last)
    }

    private static func ordered(_ lhs: ExpenseOccurrence, _ rhs: ExpenseOccurrence) -> Bool {
        (lhs.dueDate, lhs.expense.name) < (rhs.dueDate, rhs.expense.name)
    }
}
