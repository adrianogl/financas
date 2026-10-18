import Foundation

struct HomeMonthSummary: Equatable {
    let month: YearMonth
    let balance: Decimal
    let points: [BalancePoint]
    let entries: [HomeEntry]

    static func make(month: YearMonth, snapshot: IncomeSnapshot, expenses: ExpenseSnapshot, today: CalendarDay) -> HomeMonthSummary {
        let incomes = Dictionary(uniqueKeysWithValues: snapshot.incomes.map { ($0.id, $0) })
        let receipts = snapshot.receipts.filter { incomes[$0.incomeID] != nil }
        let inMonth = receipts.filter { $0.receivedOn.yearMonth == month }
        let names = Dictionary(uniqueKeysWithValues: expenses.expenses.map { ($0.id, $0.name) })
        let payments = expenses.bills.compactMap { bill -> (bill: ExpenseBill, name: String, paidOn: CalendarDay, amount: Decimal)? in
            guard let name = names[bill.expenseID], let paidOn = bill.paidOn, let amount = bill.paidAmount, paidOn.yearMonth == month else { return nil }
            return (bill, name, paidOn, amount)
        }

        let parts = Dictionary(uniqueKeysWithValues: expenses.parts.map { ($0.id, $0) })
        let partPayments = expenses.partBills.compactMap { bill -> (bill: ExpensePartBill, title: String, paidOn: CalendarDay, amount: Decimal)? in
            guard let part = parts[bill.partID], let name = names[part.expenseID],
                  let paidOn = bill.paidOn, let amount = bill.paidAmount, paidOn.yearMonth == month else { return nil }
            return (bill, "\(name) · \(part.name)", paidOn, amount)
        }

        let spendings = expenses.entries.compactMap { entry -> (entry: ExpenseEntry, name: String)? in
            guard let name = names[entry.expenseID], entry.spentOn.yearMonth == month else { return nil }
            return (entry, name)
        }

        var movements = inMonth.map { (day: $0.receivedOn.day, amount: $0.amount) }
        movements += payments.map { (day: $0.paidOn.day, amount: -$0.amount) }
        movements += partPayments.map { (day: $0.paidOn.day, amount: -$0.amount) }
        movements += spendings.map { (day: $0.entry.spentOn.day, amount: -$0.entry.amount) }
        let balance = movements.map(\.amount).reduce(0, +)

        var points = [BalancePoint(day: 1, balance: 0)]
        var running: Decimal = 0
        for (day, items) in Dictionary(grouping: movements, by: \.day).sorted(by: { $0.key < $1.key }) {
            running += items.map(\.amount).reduce(0, +)
            points.append(BalancePoint(day: day, balance: double(running)))
        }
        let lastDay = month == today.yearMonth ? today.day : month.dayCount
        if let last = points.last, lastDay > last.day {
            points.append(BalancePoint(day: lastDay, balance: double(balance)))
        }

        let incomeEntries = inMonth.compactMap { receipt -> HomeEntry? in
            guard let income = incomes[receipt.incomeID] else { return nil }
            let title = income.kind == .hourly
                ? "\(income.name) · \(IncomeFormat.monthName(receipt.month.previous))"
                : income.name
            return HomeEntry(id: receipt.id, title: title, kind: .income, date: receipt.receivedOn, amount: receipt.amount)
        }
        let expenseEntries = payments.map {
            HomeEntry(id: $0.bill.id, title: $0.name, kind: .expense, date: $0.paidOn, amount: $0.amount)
        }
        let partEntries = partPayments.map {
            HomeEntry(id: $0.bill.id, title: $0.title, kind: .expense, date: $0.paidOn, amount: $0.amount)
        }
        let spendingEntries = spendings.map {
            HomeEntry(id: $0.entry.id, title: $0.name, kind: .expense, date: $0.entry.spentOn, amount: $0.entry.amount)
        }
        let entries = (incomeEntries + expenseEntries + partEntries + spendingEntries).sorted { $0.date > $1.date }

        return HomeMonthSummary(month: month, balance: balance, points: points, entries: entries)
    }

    var chartDomain: ClosedRange<Double> {
        let values = points.map(\.balance)
        guard let low = values.min(), let high = values.max(), high > low else {
            return 0...max(1, values.max() ?? 1)
        }
        let padding = (high - low) * HomeConstants.chartPadding
        return (low - padding)...(high + padding)
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
