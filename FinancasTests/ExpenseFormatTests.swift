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

    @Test func originWithPartsUsesLatestPartPayment() {
        let taxa = S.part(S.condominio, "Taxa", position: 0)
        let agua = S.part(S.condominio, "Água", position: 1)
        var snapshot = ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: [],
            parts: [taxa, agua],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 10), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 10), amount: 85, day: 15)
            ],
            partBills: [S.partBill(taxa, S.month(2026, 10), paid: 820, on: S.day(2026, 10, 9))]
        )
        let partial = ExpenseSchedule.occurrence(of: S.condominio, in: S.month(2026, 10), snapshot: snapshot, today: S.today)!
        #expect(partial.paidOn == nil)
        #expect(ExpenseFormat.origin(partial) == "soma das partes")

        snapshot.partBills.append(S.partBill(agua, S.month(2026, 10), paid: 85, on: S.day(2026, 10, 14)))
        let paid = ExpenseSchedule.occurrence(of: S.condominio, in: S.month(2026, 10), snapshot: snapshot, today: S.today)!
        #expect(paid.paidOn == S.day(2026, 10, 14))
        #expect(ExpenseFormat.origin(paid) == "paga em qua, 14 out")
    }

    @Test func originListsTwoMonths() {
        let estimate = ExpenseEstimate.average(amount: 100, months: [S.month(2026, 7), S.month(2026, 8)])
        let base = occurrence(S.luz, in: S.month(2026, 10))
        let two = ExpenseOccurrence(expense: base.expense, month: base.month, dueDate: base.dueDate, estimate: estimate, bill: nil, status: base.status)
        #expect(ExpenseFormat.origin(two) == "estimado pela média de jul e ago")
    }

    @Test func ruleTexts() {
        #expect(ExpenseFormat.rule(S.luzTerm, estimate: .average(amount: 180, months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]), partCount: 0) == "Todo dia 13 · média de 3 meses")
        #expect(ExpenseFormat.rule(S.internetTerm, estimate: .manual(180), partCount: 0) == "Todo dia 26 · estimado")
        #expect(ExpenseFormat.rule(S.internetTerm, estimate: .fixed(120), partCount: 0) == "Todo dia 26 · valor fixo")
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
        let fixed = ExpensePartValue(part: taxa, month: S.month(2026, 10), amount: 820, origin: .fixed, isFixed: true, dueDate: S.day(2026, 10, 13), bill: nil, status: .pending)
        let water = ExpensePartValue(part: agua, month: S.month(2026, 10), amount: 110, origin: .bill, isFixed: false, dueDate: S.day(2026, 10, 13), bill: nil, status: .pending)
        let cooking = ExpensePartValue(part: gas, month: S.month(2026, 10), amount: 80, origin: .estimated, isFixed: false, dueDate: S.day(2026, 10, 13), bill: nil, status: .pending)
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
        #expect(ExpenseFormat.partCaption(water, change: 0, previous: september) == "igual a setembro")
    }

    @Test func partStatusTexts() {
        let agua = S.part(S.condominio, "Água", position: 1)
        let paidBill = S.partBill(agua, S.month(2026, 10), paid: 110, on: S.day(2026, 10, 12))
        let paid = ExpensePartValue(part: agua, month: S.month(2026, 10), amount: 110, origin: .paid, isFixed: false, dueDate: S.day(2026, 10, 13), bill: paidBill, status: .paid)
        let overdue = ExpensePartValue(part: agua, month: S.month(2026, 10), amount: 110, origin: .bill, isFixed: false, dueDate: S.day(2026, 10, 13), bill: nil, status: .overdue)
        let pending = ExpensePartValue(part: agua, month: S.month(2026, 10), amount: 110, origin: .bill, isFixed: false, dueDate: S.day(2026, 10, 26), bill: nil, status: .pending)

        #expect(ExpenseFormat.partStatus(paid) == "paga em 12/10")
        #expect(ExpenseFormat.partStatus(overdue) == "atrasada")
        #expect(ExpenseFormat.partStatus(pending) == "vence 26/10")
    }

    @Test func spendingRuleText() {
        #expect(ExpenseFormat.spendingRule(600) == "Gasto do mês · previsto R$\u{00A0}600,00")
    }

    @Test func tableAmountTexts() {
        #expect(ExpenseFormat.tableAmount(1010) == "1.010")
        #expect(ExpenseFormat.tableAmount(S.money("196.4")) == "196,40")
    }
}
