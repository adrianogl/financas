import Foundation

struct MonthComparison: Equatable, Identifiable {
    let month: YearMonth
    let income: Decimal
    let expense: Decimal
    let card: Decimal
    let isForecast: Bool

    var id: YearMonth { month }

    var balance: Decimal { income - expense }

    static func make(today: CalendarDay, incomes: IncomeSnapshot, expenses: ExpenseSnapshot, card: [CommitmentMonth]) -> [MonthComparison] {
        let cardByMonth = Dictionary(card.map { ($0.month, $0.total) }, uniquingKeysWith: +)
        var month = today.yearMonth
        for _ in 1..<HomeConstants.comparisonPastMonths {
            month = month.previous
        }

        var result: [MonthComparison] = []
        for _ in 0..<(HomeConstants.comparisonPastMonths + HomeConstants.comparisonForecastMonths) {
            let isForecast = month > today.yearMonth
            let cardTotal = isForecast ? cardByMonth[month] ?? 0 : 0
            result.append(MonthComparison(
                month: month,
                income: IncomeSchedule.summary(for: month, snapshot: incomes, today: today).expected,
                expense: ExpenseSchedule.summary(for: month, snapshot: expenses, today: today).expected + cardTotal,
                card: cardTotal,
                isForecast: isForecast
            ))
            month = month.next
        }
        return result
    }
}
