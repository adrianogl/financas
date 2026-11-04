import Foundation
import Testing
@testable import Financas

struct MonthComparisonTests {
    typealias S = IncomeSamples

    private let today = S.day(2026, 11, 4)

    private var expenses: ExpenseSnapshot {
        var snapshot = ExpenseSnapshot.empty
        snapshot.expenses = [ExpenseSamples.luz, ExpenseSamples.internet]
        snapshot.terms = [ExpenseSamples.luzTerm, ExpenseSamples.internetTerm]
        return snapshot
    }

    private func months(card: [CommitmentMonth] = []) -> [MonthComparison] {
        MonthComparison.make(today: today, incomes: S.snapshot, expenses: expenses, card: card)
    }

    @Test func coversSixMonthsUpToTodayAndThreeAhead() {
        let result = months()

        #expect(result.map(\.month) == [
            S.month(2026, 6), S.month(2026, 7), S.month(2026, 8), S.month(2026, 9), S.month(2026, 10), S.month(2026, 11),
            S.month(2026, 12), S.month(2027, 1), S.month(2027, 2),
        ])
        #expect(result.map(\.isForecast) == [false, false, false, false, false, false, true, true, true])
    }

    @Test func totalsMatchTheMonthSummariesShownOnHome() {
        for item in months() {
            let income = IncomeSchedule.summary(for: item.month, snapshot: S.snapshot, today: today)
            let expense = ExpenseSchedule.summary(for: item.month, snapshot: expenses, today: today)
            #expect(item.income == income.expected)
            #expect(item.expense == expense.expected)
        }
    }

    @Test func balanceIsIncomeMinusExpense() {
        let item = MonthComparison(month: S.month(2026, 11), income: 12600, expense: 10400, card: 0, isForecast: false)

        #expect(item.balance == 2200)
    }

    @Test func emptyDataGivesZeroedMonths() {
        let result = MonthComparison.make(today: today, incomes: IncomeSnapshot(incomes: [], amounts: [], receipts: []), expenses: .empty, card: [])

        #expect(result.count == 9)
        #expect(result.allSatisfy { $0.income == 0 && $0.expense == 0 })
    }

    @Test func forecastMonthsAddTheCardCommitment() {
        let card = [
            CommitmentMonth(month: S.month(2026, 11), installments: 999, fixed: 999),
            CommitmentMonth(month: S.month(2026, 12), installments: 500, fixed: 120),
            CommitmentMonth(month: S.month(2027, 1), installments: 300, fixed: 120),
        ]
        let result = months(card: card)
        let december = result.first { $0.month == S.month(2026, 12) }!
        let january = result.first { $0.month == S.month(2027, 1) }!
        let february = result.first { $0.month == S.month(2027, 2) }!
        let november = result.first { $0.month == S.month(2026, 11) }!
        let bills = { (month: YearMonth) in ExpenseSchedule.summary(for: month, snapshot: expenses, today: today).expected }

        #expect(december.card == 620)
        #expect(december.expense == bills(S.month(2026, 12)) + 620)
        #expect(january.card == 420)
        #expect(february.card == 0)
        #expect(november.card == 0)
        #expect(november.expense == bills(S.month(2026, 11)))
    }
}
