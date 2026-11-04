import Foundation
import Testing
@testable import Financas

struct QuickSpendingTests {
    typealias S = ExpenseSamples

    private let padaria = Expense(id: UUID(), name: "Padaria", startMonth: S.month(2026, 10), kind: .spending)
    private let mercado = Expense(id: UUID(), name: "Mercado", startMonth: S.month(2026, 10), kind: .spending)

    private func entry(_ expense: Expense, _ day: CalendarDay) -> ExpenseEntry {
        ExpenseEntry(id: UUID(), expenseID: expense.id, spentOn: day, amount: 10)
    }

    @Test func defaultsToTheLastUsedSpending() {
        let entries = [entry(mercado, S.day(2026, 10, 3)), entry(padaria, S.day(2026, 10, 15)), entry(mercado, S.day(2026, 10, 10))]

        #expect(QuickSpending.defaultExpense(options: [mercado, padaria], entries: entries) == padaria)
    }

    @Test func ignoresEntriesOfSpendingsThatAreNotOptions() {
        let ended = Expense(id: UUID(), name: "Antigo", startMonth: S.month(2026, 1), kind: .spending)
        let entries = [entry(ended, S.day(2026, 10, 16)), entry(mercado, S.day(2026, 10, 1))]

        #expect(QuickSpending.defaultExpense(options: [mercado, padaria], entries: entries) == mercado)
    }

    @Test func fallsBackToTheFirstOptionWithoutEntries() {
        #expect(QuickSpending.defaultExpense(options: [mercado, padaria], entries: []) == mercado)
        #expect(QuickSpending.defaultExpense(options: [], entries: []) == nil)
    }
}
