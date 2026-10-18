import Foundation
import Testing
@testable import Financas

struct ExpenseFormatTests {
    typealias S = ExpenseSamples

    private func occurrence(_ expense: Expense, in month: YearMonth, bills: [ExpenseBill] = []) -> ExpenseOccurrence {
        let snapshot = ExpenseSnapshot(expenses: S.snapshot.expenses, terms: S.snapshot.terms, bills: bills)
        return ExpenseSchedule.occurrence(of: expense, in: month, snapshot: snapshot, today: S.today)!
    }

    private var history: [ExpenseBill] {
        [
            S.paid(S.luz, S.month(2026, 7), 170, on: S.day(2026, 7, 13)),
            S.paid(S.luz, S.month(2026, 8), 180, on: S.day(2026, 8, 13)),
            S.paid(S.luz, S.month(2026, 9), 190, on: S.day(2026, 9, 14))
        ]
    }

    @Test func originTexts() {
        #expect(ExpenseFormat.origin(occurrence(S.luz, in: S.month(2026, 10), bills: history)) == "estimado pela média de jul, ago e set")
        #expect(ExpenseFormat.origin(occurrence(S.internet, in: S.month(2026, 10))) == "estimado")

        let bill = S.bill(S.luz, S.month(2026, 10), 210, due: S.day(2026, 10, 20))
        #expect(ExpenseFormat.origin(occurrence(S.luz, in: S.month(2026, 10), bills: history + [bill])) == "conta lançada")

        let paid = S.paid(S.luz, S.month(2026, 9), 190, on: S.day(2026, 9, 14))
        #expect(ExpenseFormat.origin(occurrence(S.luz, in: S.month(2026, 9), bills: [paid])) == "paga em seg, 14 set")
    }

    @Test func originListsTwoMonths() {
        let estimate = ExpenseEstimate.average(amount: 100, months: [S.month(2026, 7), S.month(2026, 8)])
        let base = occurrence(S.luz, in: S.month(2026, 10))
        let two = ExpenseOccurrence(expense: base.expense, month: base.month, dueDate: base.dueDate, estimate: estimate, bill: nil, status: base.status)
        #expect(ExpenseFormat.origin(two) == "estimado pela média de jul e ago")
    }

    @Test func ruleTexts() {
        #expect(ExpenseFormat.rule(S.luzTerm, estimate: .average(amount: 180, months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)])) == "Todo dia 13 · média de 3 meses")
        #expect(ExpenseFormat.rule(S.internetTerm, estimate: .manual(180)) == "Todo dia 26 · estimado")
        #expect(ExpenseFormat.rule(S.internetTerm, estimate: .fixed(120)) == "Todo dia 26 · valor fixo")
    }

    @Test func originForFixedExpense() {
        var internet = S.internet
        internet.isFixed = true
        let snapshot = ExpenseSnapshot(expenses: [internet], terms: S.snapshot.terms, bills: [])
        let october = ExpenseSchedule.occurrence(of: internet, in: S.month(2026, 10), snapshot: snapshot, today: S.today)!
        #expect(ExpenseFormat.origin(october) == "valor fixo")
    }

    @Test func titleShowsMonthOnlyForPreviousMonths() {
        #expect(ExpenseFormat.occurrenceTitle(occurrence(S.luz, in: S.month(2026, 10)), today: S.today) == "Luz")
        #expect(ExpenseFormat.occurrenceTitle(occurrence(S.luz, in: S.month(2026, 9)), today: S.today) == "Luz · setembro")
    }

    @Test func partTexts() {
        let taxa = S.part(S.condominio, "Taxa", position: 0)
        let agua = S.part(S.condominio, "Água", position: 1)
        let gas = S.part(S.condominio, "Gás", position: 2)
        let fixed = ExpensePartValue(part: taxa, amount: 820, origin: .fixed, isFixed: true)
        let water = ExpensePartValue(part: agua, amount: 110, origin: .bill, isFixed: false)
        let cooking = ExpensePartValue(part: gas, amount: 80, origin: .estimated, isFixed: false)
        let september = S.month(2026, 9)

        #expect(ExpenseFormat.rule(S.condominioTerm, estimate: .parts(1010), partCount: 3) == "Todo dia 10 · 3 partes")
        #expect(ExpenseFormat.rule(S.condominioTerm, estimate: .parts(820), partCount: 1) == "Todo dia 10 · 1 parte")

        let base = occurrence(S.condominio, in: S.month(2026, 10))
        let summed = ExpenseOccurrence(expense: base.expense, month: base.month, dueDate: base.dueDate, estimate: .parts(1010), bill: nil, status: base.status)
        #expect(ExpenseFormat.origin(summed) == "soma das partes")

        #expect(ExpenseFormat.partNames([fixed, water, cooking]) == "taxa, água e gás")
        #expect(ExpenseFormat.partNames([fixed, water]) == "taxa e água")

        #expect(ExpenseFormat.partCaption(fixed, change: 10, previous: september) == "fixo")
        #expect(ExpenseFormat.partCaption(water, change: 30, previous: september) == "▲ R$\u{00A0}30,00 vs. setembro")
        #expect(ExpenseFormat.partCaption(water, change: -5, previous: september) == "▼ R$\u{00A0}5,00 vs. setembro")
        #expect(ExpenseFormat.partCaption(cooking, change: nil, previous: september) == "varia")
    }
}
