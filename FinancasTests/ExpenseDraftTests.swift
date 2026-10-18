import Foundation
import Testing
@testable import Financas

struct ExpenseDraftTests {
    typealias S = ExpenseSamples

    @Test func newDraftBuildsTermFromStartMonth() {
        var draft = ExpenseDraft(today: S.today)
        draft.name = "  Água "
        draft.estimatedAmount = 90
        draft.dayOfMonth = 8
        draft.startMonth = S.month(2026, 11)

        let (expense, term) = draft.build(today: S.today)

        #expect(expense.name == "Água")
        #expect(expense.startMonth == S.month(2026, 11))
        #expect(term?.validFrom == S.month(2026, 11))
        #expect(term?.averageFrom == S.month(2026, 11))
        #expect(term?.estimatedAmount == 90)
        #expect(term?.dayOfMonth == 8)
        #expect(term?.expenseID == expense.id)
    }

    @Test func editingEstimateStartsAverageNextMonth() {
        var draft = ExpenseDraft(expense: S.luz, snapshot: S.snapshot, today: S.today)
        #expect(draft.estimatedAmount == 180)
        #expect(draft.dayOfMonth == 13)
        draft.estimatedAmount = 200

        let term = draft.build(today: S.today).1

        #expect(term?.validFrom == S.month(2026, 10))
        #expect(term?.averageFrom == S.month(2026, 11))
        #expect(term?.estimatedAmount == 200)
        #expect(term?.id != S.luzTerm.id)
    }

    @Test func editingOnlyDayKeepsAverageFrom() {
        let current = S.term(S.luz, from: S.month(2026, 8), day: 13, estimated: 180, averageFrom: S.month(2026, 9))
        let snapshot = ExpenseSnapshot(expenses: [S.luz], terms: [current], bills: [])
        var draft = ExpenseDraft(expense: S.luz, snapshot: snapshot, today: S.today)
        draft.dayOfMonth = 20

        let term = draft.build(today: S.today).1

        #expect(term?.validFrom == S.month(2026, 10))
        #expect(term?.averageFrom == S.month(2026, 9))
        #expect(term?.dayOfMonth == 20)
    }

    @Test func editingFutureExpenseReplacesInitialTerm() {
        let future = Expense(id: UUID(), name: "Seguro", startMonth: S.month(2026, 12))
        let initial = S.term(future, from: S.month(2026, 12), day: 5, estimated: 100)
        let snapshot = ExpenseSnapshot(expenses: [future], terms: [initial], bills: [])
        var draft = ExpenseDraft(expense: future, snapshot: snapshot, today: S.today)
        draft.estimatedAmount = 120

        let term = draft.build(today: S.today).1

        #expect(term?.id == initial.id)
        #expect(term?.validFrom == S.month(2026, 12))
        #expect(term?.averageFrom == S.month(2026, 12))
        #expect(term?.estimatedAmount == 120)
    }

    @Test func secondEditSameMonthReusesTerm() {
        var first = ExpenseDraft(expense: S.luz, snapshot: S.snapshot, today: S.today)
        first.estimatedAmount = 200
        let edited = first.build(today: S.today).1!
        let snapshot = ExpenseSnapshot(expenses: [S.luz], terms: [S.luzTerm, edited], bills: [])

        var second = ExpenseDraft(expense: S.luz, snapshot: snapshot, today: S.today)
        second.dayOfMonth = 20
        let term = second.build(today: S.today).1

        #expect(term?.id == edited.id)
        #expect(term?.validFrom == S.month(2026, 10))
        #expect(term?.averageFrom == S.month(2026, 11))
        #expect(term?.estimatedAmount == 200)
        #expect(term?.dayOfMonth == 20)
    }

    @Test func unchangedEditReturnsNoTerm() {
        var draft = ExpenseDraft(expense: S.luz, snapshot: S.snapshot, today: S.today)
        draft.name = "Energia"

        let (expense, term) = draft.build(today: S.today)

        #expect(expense.name == "Energia")
        #expect(term == nil)
    }

    @Test func validationMessages() {
        var draft = ExpenseDraft(today: S.today)
        #expect(draft.validationMessage == "Dê um nome para a despesa.")
        draft.name = "Água"
        #expect(draft.validationMessage == "Informe um valor maior que zero.")
        draft.estimatedAmount = 0
        #expect(draft.validationMessage == "Informe um valor maior que zero.")
        draft.estimatedAmount = 90
        #expect(draft.validationMessage == nil)
        draft.endMonth = draft.startMonth.previous
        #expect(draft.validationMessage == "O mês de fim precisa ser depois do início.")
    }
}
