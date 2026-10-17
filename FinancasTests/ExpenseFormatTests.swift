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
    }

    @Test func titleShowsMonthOnlyForPreviousMonths() {
        #expect(ExpenseFormat.occurrenceTitle(occurrence(S.luz, in: S.month(2026, 10)), today: S.today) == "Luz")
        #expect(ExpenseFormat.occurrenceTitle(occurrence(S.luz, in: S.month(2026, 9)), today: S.today) == "Luz · setembro")
    }
}
