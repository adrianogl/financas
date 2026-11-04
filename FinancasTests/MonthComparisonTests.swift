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

    private func months() -> [MonthComparison] {
        MonthComparison.make(today: today, incomes: S.snapshot, expenses: expenses)
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
        let item = MonthComparison(month: S.month(2026, 11), income: 12600, expense: 10400, isForecast: false)

        #expect(item.balance == 2200)
    }

    @Test func emptyDataGivesZeroedMonths() {
        let result = MonthComparison.make(today: today, incomes: IncomeSnapshot(incomes: [], amounts: [], receipts: []), expenses: .empty)

        #expect(result.count == 9)
        #expect(result.allSatisfy { $0.income == 0 && $0.expense == 0 })
    }
}
