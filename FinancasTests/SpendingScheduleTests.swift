import Foundation
import Testing
@testable import Financas

struct SpendingScheduleTests {
    typealias S = ExpenseSamples

    private let abastecimento = Expense(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
        name: "Abastecimento",
        startMonth: S.month(2026, 10),
        kind: .spending
    )

    private func entry(_ amount: Decimal, _ day: CalendarDay) -> ExpenseEntry {
        ExpenseEntry(id: UUID(), expenseID: abastecimento.id, spentOn: day, amount: amount)
    }

    private func snapshot(start: YearMonth = S.month(2026, 10), entries: [ExpenseEntry]? = nil) -> ExpenseSnapshot {
        var expense = abastecimento
        expense.startMonth = start
        return ExpenseSnapshot(
            expenses: [expense],
            terms: [S.term(expense, from: start, day: 1, estimated: 600)],
            bills: [],
            entries: entries ?? [
                entry(130, S.day(2026, 10, 2)),
                entry(140, S.day(2026, 10, 10)),
                entry(150, S.day(2026, 10, 17)),
            ]
        )
    }

    @Test func spentAndRemainingInCurrentMonth() throws {
        let data = snapshot()
        let result = try #require(SpendingSchedule.month(of: data.expenses[0], in: S.month(2026, 10), snapshot: data, today: S.today))
        #expect(result.expected == 600)
        #expect(result.spent == 420)
        #expect(result.remaining == 180)
        #expect(!result.isOver)
        #expect(result.entries.map(\.spentOn.day) == [17, 10, 2])
    }

    @Test func pastMonthHasNoRemaining() throws {
        let data = snapshot(start: S.month(2026, 9), entries: [entry(100, S.day(2026, 9, 5))])
        let result = try #require(SpendingSchedule.month(of: data.expenses[0], in: S.month(2026, 9), snapshot: data, today: S.today))
        #expect(result.spent == 100)
        #expect(result.remaining == 0)
    }

    @Test func overExpected() throws {
        let data = snapshot(entries: [entry(650, S.day(2026, 10, 3))])
        let result = try #require(SpendingSchedule.month(of: data.expenses[0], in: S.month(2026, 10), snapshot: data, today: S.today))
        #expect(result.isOver)
        #expect(result.excess == 50)
        #expect(result.remaining == 0)
    }

    @Test func entryCountsInMonthOfItsDate() throws {
        let data = snapshot(entries: [entry(100, S.day(2026, 10, 31)), entry(70, S.day(2026, 11, 1))])
        let expense = data.expenses[0]
        let october = try #require(SpendingSchedule.month(of: expense, in: S.month(2026, 10), snapshot: data, today: S.today))
        let november = try #require(SpendingSchedule.month(of: expense, in: S.month(2026, 11), snapshot: data, today: S.today))
        #expect(october.spent == 100)
        #expect(november.spent == 70)
    }

    @Test func nilOutsideExpensePeriod() {
        let data = snapshot()
        #expect(SpendingSchedule.month(of: data.expenses[0], in: S.month(2026, 9), snapshot: data, today: S.today) == nil)
    }

    @Test func monthsSkipBills() {
        var data = snapshot()
        data.expenses.append(S.luz)
        data.terms.append(S.luzTerm)
        #expect(SpendingSchedule.months(in: S.month(2026, 10), snapshot: data, today: S.today).map(\.expense.name) == ["Abastecimento"])
    }

    @Test func historyStopsAtStartAndKeepsSix() {
        let long = snapshot(start: S.month(2026, 1))
        let months = SpendingSchedule.history(of: long.expenses[0], through: S.month(2026, 10), snapshot: long, today: S.today)
        #expect(months.map(\.month) == (5...10).map { S.month(2026, $0) })

        let short = snapshot(start: S.month(2026, 9))
        let recent = SpendingSchedule.history(of: short.expenses[0], through: S.month(2026, 10), snapshot: short, today: S.today)
        #expect(recent.map(\.month) == [S.month(2026, 9), S.month(2026, 10)])
    }

    @Test func summaryIncludesSpending() {
        let data = snapshot()
        let result = ExpenseSchedule.summary(for: S.month(2026, 10), snapshot: data, today: S.today)
        #expect(result.paid == 420)
        #expect(result.remaining == 180)
        #expect(result.expected == 600)
        #expect(result.overdueCount == 0)
        #expect(result.next == nil)
    }
}
