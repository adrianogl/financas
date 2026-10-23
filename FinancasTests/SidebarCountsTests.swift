import Testing
@testable import Financas

struct SidebarCountsTests {
    @Test func countsOpenOnly() {
        let october = IncomeSamples.month(2026, 10)
        var incomeSnapshot = IncomeSamples.snapshot
        incomeSnapshot.receipts = [IncomeSamples.receipt(IncomeSamples.fixed, october, amount: 100)]
        let incomes = IncomeSchedule.occurrences(in: october, snapshot: incomeSnapshot, today: IncomeSamples.today)

        var expenseSnapshot = ExpenseSamples.snapshot
        expenseSnapshot.bills = [
            ExpenseSamples.paid(ExpenseSamples.condominio, october, 1150, on: ExpenseSamples.day(2026, 10, 9))
        ]
        let expenses = ExpenseSchedule.occurrences(in: october, snapshot: expenseSnapshot, today: ExpenseSamples.today)

        let counts = SidebarCounts(incomes: incomes, expenses: expenses, overdue: 4, cards: 3)

        #expect(counts.incomes == 1)
        #expect(counts.expenses == 2)
        #expect(counts.overdue == 4)
        #expect(counts.cards == 3)
    }
}
