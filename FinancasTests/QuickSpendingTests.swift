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

    private let farmacia = Expense(id: UUID(), name: "Farmácia", startMonth: S.month(2026, 10), kind: .spending)
    private let avulsos = Expense(id: UUID(), name: "Avulsos", startMonth: S.month(2026, 10), kind: .spending)

    @Test func ranksLastUsedFirstThenMostFrequentThenByName() {
        let today = S.day(2026, 11, 4)
        let entries = [
            entry(mercado, S.day(2026, 10, 20)), entry(mercado, S.day(2026, 10, 25)), entry(mercado, S.day(2026, 11, 1)),
            entry(farmacia, S.day(2026, 10, 30)),
            entry(padaria, S.day(2026, 11, 3)),
            entry(avulsos, S.day(2026, 9, 1)), entry(avulsos, S.day(2026, 9, 2)), entry(avulsos, S.day(2026, 9, 3)), entry(avulsos, S.day(2026, 9, 4)),
        ]

        let ranked = QuickSpending.ranked(options: [avulsos, farmacia, mercado, padaria], entries: entries, today: today)

        #expect(ranked.map(\.name) == ["Padaria", "Mercado", "Farmácia", "Avulsos"])
    }

    @Test func searchIgnoresAccentsAndCase() {
        let options = [avulsos, farmacia, mercado, padaria]

        #expect(QuickSpending.matching(options, query: "farma").map(\.name) == ["Farmácia"])
        #expect(QuickSpending.matching(options, query: "PAD").map(\.name) == ["Padaria"])
        #expect(QuickSpending.matching(options, query: "  ").count == 4)
    }

    @Test func amountKeepsTwoDecimalPlaces() {
        #expect(QuickSpending.amount(from: 12.5) == Decimal(string: "12.50"))
        #expect(QuickSpending.amount(from: 0.1 + 0.2) == Decimal(string: "0.30"))
        #expect(QuickSpending.amount(from: 19.999) == Decimal(string: "20.00"))
    }

    @Test func negativeAmountStaysNegativeSoTheIntentRejectsIt() {
        #expect(QuickSpending.amount(from: -12.5) < 0)
    }

    @Test func subtitleShowsTheMonthTotal() {
        #expect(QuickSpending.subtitle(spent: S.money("148.3"), month: S.month(2026, 11)) == "R$\u{00A0}148,30 em novembro")
        #expect(QuickSpending.subtitle(spent: 0, month: S.month(2026, 11)) == "R$\u{00A0}0,00 em novembro")
    }
}
