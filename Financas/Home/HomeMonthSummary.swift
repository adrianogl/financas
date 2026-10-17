import Foundation

struct HomeMonthSummary: Equatable {
    let month: YearMonth
    let balance: Decimal
    let points: [BalancePoint]
    let entries: [HomeEntry]

    static func make(month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> HomeMonthSummary {
        let incomes = Dictionary(uniqueKeysWithValues: snapshot.incomes.map { ($0.id, $0) })
        let receipts = snapshot.receipts.filter { incomes[$0.incomeID] != nil }
        let opening = receipts.filter { $0.receivedOn.yearMonth < month }.map(\.amount).reduce(0, +)
        let inMonth = receipts.filter { $0.receivedOn.yearMonth == month }
        let balance = opening + inMonth.map(\.amount).reduce(0, +)

        var points = [BalancePoint(day: 1, balance: double(opening))]
        var running = opening
        for (day, items) in Dictionary(grouping: inMonth, by: \.receivedOn.day).sorted(by: { $0.key < $1.key }) {
            running += items.map(\.amount).reduce(0, +)
            points.append(BalancePoint(day: day, balance: double(running)))
        }
        let lastDay = month == today.yearMonth ? today.day : month.dayCount
        if let last = points.last, lastDay > last.day {
            points.append(BalancePoint(day: lastDay, balance: double(balance)))
        }

        let entries = inMonth
            .sorted { $0.receivedOn > $1.receivedOn }
            .compactMap { receipt -> HomeEntry? in
                guard let income = incomes[receipt.incomeID] else { return nil }
                let title = income.kind == .hourly
                    ? "\(income.name) · \(IncomeFormat.monthName(receipt.month.previous))"
                    : income.name
                return HomeEntry(id: receipt.id, title: title, kind: income.kind, receivedOn: receipt.receivedOn, amount: receipt.amount)
            }

        return HomeMonthSummary(month: month, balance: balance, points: points, entries: entries)
    }

    private static func double(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
