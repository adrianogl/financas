import Foundation
import Testing
@testable import Financas

struct OverdueSummaryTests {
    private typealias S = ExpenseSamples

    private var overdueExpenses: [ExpensePayable] {
        ExpenseSchedule.occurrences(in: S.today.yearMonth, snapshot: S.snapshot, today: S.today)
            .filter { $0.status == .overdue }
            .map { ExpensePayable(occurrence: $0, today: S.today) }
    }

    private var overdueIncome: IncomeOccurrence {
        IncomeOccurrence(
            income: IncomeSamples.fixed,
            month: S.month(2026, 10),
            referenceMonth: nil,
            dueDate: S.day(2026, 10, 1),
            expectedAmount: 500,
            businessDays: nil,
            hourlyRate: nil,
            receipt: nil,
            status: .overdue
        )
    }

    @Test func emptyWhenBothListsAreEmpty() {
        let summary = OverdueSummary(incomes: [], expenses: [])
        #expect(summary.isEmpty)
        #expect(!summary.showsIncomes)
        #expect(!summary.showsExpenses)
        #expect(!summary.showsIncoming)
        #expect(!summary.showsOutgoing)
        #expect(summary.badgeCount == 0)
    }

    @Test func onlyExpensesShowOnlyOutgoing() {
        let summary = OverdueSummary(incomes: [], expenses: overdueExpenses)
        #expect(!summary.isEmpty)
        #expect(!summary.showsIncomes)
        #expect(summary.showsExpenses)
        #expect(!summary.showsIncoming)
        #expect(summary.showsOutgoing)
        #expect(summary.outgoing == S.money("1330"))
        #expect(summary.badgeCount == 2)
    }

    @Test func onlyIncomesShowOnlyIncoming() {
        let summary = OverdueSummary(incomes: [overdueIncome], expenses: [])
        #expect(summary.showsIncomes)
        #expect(!summary.showsExpenses)
        #expect(summary.showsIncoming)
        #expect(!summary.showsOutgoing)
        #expect(summary.incoming == 500)
    }

    @Test func badgeSumsBothLists() {
        let summary = OverdueSummary(incomes: [overdueIncome], expenses: overdueExpenses)
        #expect(summary.badgeCount == 3)
        #expect(summary.showsIncoming)
        #expect(summary.showsOutgoing)
    }
}
