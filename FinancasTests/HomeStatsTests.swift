import Foundation
import Testing
@testable import Financas

@MainActor
struct HomeStatsTests {
    private let today = ExpenseSamples.today

    private func stores(loaded: Bool) async -> (IncomeStore, ExpenseStore) {
        var incomeSnapshot = IncomeSamples.snapshot
        incomeSnapshot.receipts = [IncomeSamples.receipt(IncomeSamples.fixed, IncomeSamples.month(2026, 10), amount: 1000, on: today)]
        let incomes = IncomeStore(service: FakeIncomeService(snapshot: incomeSnapshot), today: { [today] in today })
        let expenses = ExpenseStore(service: FakeExpenseService())
        if loaded {
            await incomes.load()
            await expenses.load()
        }
        return (incomes, expenses)
    }

    @Test func showsDashWhileLoading() async {
        let (incomes, expenses) = await stores(loaded: false)
        let stats = HomeStats(incomes: incomes, expenses: expenses)
        for stat in [stats.balance, stats.receivable, stats.payable, stats.overdue] {
            #expect(stat.value == "—")
            #expect(stat.caption == "")
            #expect(stat.badge == nil)
            #expect(!stat.isWarning)
        }
    }

    @Test func fillsValuesWhenLoaded() async {
        let (incomes, expenses) = await stores(loaded: true)
        let stats = HomeStats(incomes: incomes, expenses: expenses)
        let summary = incomes.summary(for: incomes.selectedMonth)
        let expenseSummary = expenses.summary(for: incomes.selectedMonth, today: today)

        #expect(stats.balance.title == "Saldo")
        #expect(stats.balance.value == IncomeFormat.currency(1000))
        #expect(stats.balance.caption == "recebido menos pago em outubro")
        #expect(stats.receivable.title == "Falta receber")
        #expect(stats.receivable.value == IncomeFormat.currency(summary.remaining))
        #expect(stats.receivable.caption == HomeStatText.expected(summary.expected))
        #expect(stats.payable.title == "Falta pagar")
        #expect(stats.payable.value == IncomeFormat.currency(expenseSummary.remaining))
        #expect(stats.payable.badge == HomeStatText.overdueBadge(expenseSummary.overdueCount))
        #expect(stats.overdue.title == "Atrasadas")
        #expect(stats.overdue.value == "\(incomes.overdueOccurrences.count + expenses.overdueOccurrences(today: today).count)")
        #expect(stats.overdue.isWarning)
        #expect(stats.overdue.caption == "Luz · Condomínio")
    }
}
