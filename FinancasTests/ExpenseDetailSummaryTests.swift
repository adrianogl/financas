import Testing
@testable import Financas

struct ExpenseDetailSummaryTests {
    private func summary(bills: [ExpenseBill] = []) throws -> ExpenseDetailSummary {
        var snapshot = ExpenseSamples.snapshot
        snapshot.bills = bills
        let occurrence = try #require(ExpenseSchedule.occurrence(
            of: ExpenseSamples.luz, in: ExpenseSamples.month(2026, 10), snapshot: snapshot, today: ExpenseSamples.today
        ))
        return ExpenseDetailSummary.make(occurrence: occurrence, snapshot: snapshot)
    }

    @Test func ruleUsesTermDay() throws {
        #expect(try summary().rule == "Despesa fixa · vence dia 13")
    }

    @Test func historyUsesPaidAmounts() throws {
        let luz = ExpenseSamples.luz
        let result = try summary(bills: [
            ExpenseSamples.paid(luz, ExpenseSamples.month(2026, 7), ExpenseSamples.money("196.40"), on: ExpenseSamples.day(2026, 7, 13)),
            ExpenseSamples.paid(luz, ExpenseSamples.month(2026, 9), ExpenseSamples.money("219.80"), on: ExpenseSamples.day(2026, 9, 13))
        ])
        #expect(result.history == [
            DetailHistoryEntry(month: ExpenseSamples.month(2026, 9), amount: ExpenseSamples.money("219.80")),
            DetailHistoryEntry(month: ExpenseSamples.month(2026, 8), amount: nil),
            DetailHistoryEntry(month: ExpenseSamples.month(2026, 7), amount: ExpenseSamples.money("196.40"))
        ])
    }

    @Test func partsUseRuleWithPartCountAndPartsHistory() throws {
        let condominio = ExpenseSamples.condominio
        let taxa = ExpenseSamples.part(condominio, "Taxa", position: 0)
        let agua = ExpenseSamples.part(condominio, "Água", position: 1)
        var snapshot = ExpenseSamples.snapshot
        snapshot.parts = [taxa, agua]
        snapshot.partTerms = [
            ExpenseSamples.partTerm(taxa, from: ExpenseSamples.month(2026, 10), amount: 820, isFixed: true),
            ExpenseSamples.partTerm(agua, from: ExpenseSamples.month(2026, 10), amount: 80)
        ]
        let occurrence = try #require(ExpenseSchedule.occurrence(
            of: condominio, in: ExpenseSamples.month(2026, 10), snapshot: snapshot, today: ExpenseSamples.today
        ))
        let result = ExpenseDetailSummary.make(occurrence: occurrence, snapshot: snapshot)
        #expect(result.rule == "Todo dia 10 · 2 partes")
        #expect(result.partsHistory?.columns == [taxa, agua])
    }

    @Test func withoutPartsHasNoPartsHistory() throws {
        #expect(try summary().partsHistory == nil)
    }
}
