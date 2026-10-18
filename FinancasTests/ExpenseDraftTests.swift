import Foundation
import Testing
@testable import Financas

struct ExpenseDraftTests {
    typealias S = ExpenseSamples

    private let taxa = S.part(S.condominio, "Taxa", position: 0)
    private let agua = S.part(S.condominio, "Água", position: 1)
    private let gas = S.part(S.condominio, "Gás", position: 2)

    private func condominioSnapshot(bills: [ExpenseBill] = [], gasTerms: [ExpensePartTerm]? = nil) -> ExpenseSnapshot {
        ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: bills,
            parts: [taxa, agua, gas],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 10), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 10), amount: 85)
            ] + (gasTerms ?? [S.partTerm(gas, from: S.month(2026, 10), amount: 80)])
        )
    }

    private func editCondominio(_ snapshot: ExpenseSnapshot) -> ExpenseDraft {
        ExpenseDraft(expense: S.condominio, snapshot: snapshot, today: S.today)
    }

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

    @Test func newDraftStartsFixed() {
        var draft = ExpenseDraft(today: S.today)
        #expect(draft.isFixed)
        draft.name = "Internet"
        draft.estimatedAmount = 120
        #expect(draft.build(today: S.today).0.isFixed)
    }

    @Test func switchingToVariesUpdatesOnlyTheExpense() {
        var internet = S.internet
        internet.isFixed = true
        let snapshot = ExpenseSnapshot(expenses: [internet], terms: S.snapshot.terms, bills: [])
        var draft = ExpenseDraft(expense: internet, snapshot: snapshot, today: S.today)
        #expect(draft.isFixed)
        draft.isFixed = false

        let (expense, term) = draft.build(today: S.today)

        #expect(!expense.isFixed)
        #expect(term == nil)
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

    @Test func newBillWithPartsBuildsTermsFromStart() throws {
        var draft = ExpenseDraft(today: S.today)
        #expect(draft.kind == .bill)
        draft.name = "Condomínio"
        draft.dayOfMonth = 10
        draft.startMonth = S.month(2026, 11)
        draft.addPart()
        draft.addPart()
        #expect(draft.parts[0].isFixed == false)
        draft.parts[0].name = "Taxa"
        draft.parts[0].isFixed = true
        draft.parts[0].amount = 820
        draft.parts[1].name = "Água"
        draft.parts[1].amount = 85
        #expect(draft.validationMessage == nil)

        let (expense, term) = draft.build(today: S.today)
        let changes = draft.buildParts(today: S.today)

        #expect(term?.validFrom == S.month(2026, 11))
        #expect(changes.parts.map(\.name) == ["Taxa", "Água"])
        #expect(changes.parts.map(\.position) == [0, 1])
        #expect(changes.parts.allSatisfy { $0.expenseID == expense.id })
        #expect(changes.terms.count == 2)
        #expect(changes.terms.map(\.partID) == changes.parts.map(\.id))
        #expect(changes.terms.map(\.amount) == [820, 85])
        #expect(changes.terms.map(\.isFixed) == [true, false])
        #expect(changes.terms.allSatisfy { $0.validFrom == S.month(2026, 11) && $0.averageFrom == S.month(2026, 11) && $0.isActive })
    }

    @Test func editingDraftLoadsActiveParts() {
        let draft = editCondominio(condominioSnapshot())

        #expect(draft.kind == .bill)
        #expect(draft.effectiveMonth == S.month(2026, 10))
        #expect(draft.parts == [
            ExpensePartDraft(id: taxa.id, name: "Taxa", isFixed: true, amount: 820),
            ExpensePartDraft(id: agua.id, name: "Água", isFixed: false, amount: 85),
            ExpensePartDraft(id: gas.id, name: "Gás", isFixed: false, amount: 80)
        ])
        #expect(draft.buildParts(today: S.today) == ExpensePartChanges(parts: [], terms: []))
        #expect(draft.build(today: S.today).1 == nil)
    }

    @Test func editingPartAmountStartsAverageNextMonth() throws {
        var draft = editCondominio(condominioSnapshot())
        draft.parts[1].amount = 95

        let changes = draft.buildParts(today: S.today)

        #expect(changes.parts.isEmpty)
        let term = try #require(changes.terms.first)
        #expect(changes.terms.count == 1)
        #expect(term.partID == agua.id)
        #expect(term.amount == 95)
        #expect(term.validFrom == S.month(2026, 10))
        #expect(term.averageFrom == S.month(2026, 11))
        #expect(draft.build(today: S.today).1 == nil)
    }

    @Test func switchingPartToFixedKeepsAverageFrom() throws {
        let snapshot = condominioSnapshot()
        var draft = editCondominio(snapshot)
        draft.parts[1].isFixed = true

        let term = try #require(draft.buildParts(today: S.today).terms.first)

        #expect(term.isFixed)
        #expect(term.averageFrom == S.month(2026, 10))
        #expect(term.id == snapshot.partTerms.first { $0.partID == agua.id }?.id)
    }

    @Test func changesWaitWhenCurrentMonthIsRegistered() throws {
        let paid = S.paid(S.condominio, S.month(2026, 10), 985, on: S.day(2026, 10, 10))
        var draft = editCondominio(condominioSnapshot(bills: [paid]))
        #expect(draft.effectiveMonth == S.month(2026, 11))
        draft.parts[1].amount = 95

        let term = try #require(draft.buildParts(today: S.today).terms.first)

        #expect(term.validFrom == S.month(2026, 11))
        #expect(term.averageFrom == S.month(2026, 11))
    }

    @Test func renamingPartUpdatesName() {
        var draft = editCondominio(condominioSnapshot())
        draft.parts[1].name = " Água fria "

        let changes = draft.buildParts(today: S.today)

        #expect(changes.parts == [ExpensePart(id: agua.id, expenseID: S.condominio.id, name: "Água fria", position: 1)])
        #expect(changes.terms.isEmpty)
    }

    @Test func removingPartDeactivatesIt() throws {
        var draft = editCondominio(condominioSnapshot())
        draft.removePart(id: gas.id)

        let changes = draft.buildParts(today: S.today)

        let term = try #require(changes.terms.first)
        #expect(changes.terms.count == 1)
        #expect(term.partID == gas.id)
        #expect(!term.isActive)
        #expect(term.amount == 80)
        #expect(term.validFrom == S.month(2026, 10))
        #expect(draft.estimatedAmount == S.condominioTerm.estimatedAmount)
    }

    @Test func removingLastPartFallsBackToSum() throws {
        var draft = editCondominio(condominioSnapshot())
        draft.removePart(id: taxa.id)
        draft.removePart(id: agua.id)
        draft.removePart(id: gas.id)

        #expect(draft.parts.isEmpty)
        #expect(draft.estimatedAmount == 985)
        #expect(!draft.isFixed)
        #expect(draft.validationMessage == nil)

        let (expense, built) = draft.build(today: S.today)
        let term = try #require(built)
        #expect(!expense.isFixed)
        #expect(term.estimatedAmount == 985)
        #expect(term.validFrom == S.month(2026, 10))
        #expect(term.averageFrom == S.month(2026, 11))
        #expect(draft.buildParts(today: S.today).terms.filter { !$0.isActive }.count == 3)
    }

    @Test func readdingSameNameReactivatesPart() throws {
        let gasTerms = [
            S.partTerm(gas, from: S.month(2026, 7), amount: 80, averageFrom: S.month(2026, 8)),
            S.partTerm(gas, from: S.month(2026, 9), amount: 80, averageFrom: S.month(2026, 9), isActive: false)
        ]
        var draft = editCondominio(condominioSnapshot(gasTerms: gasTerms))
        #expect(draft.parts.map(\.name) == ["Taxa", "Água"])
        draft.addPart()
        draft.parts[2].name = " gás "
        draft.parts[2].amount = 80

        let changes = draft.buildParts(today: S.today)

        let term = try #require(changes.terms.first)
        #expect(changes.terms.count == 1)
        #expect(term.partID == gas.id)
        #expect(term.isActive)
        #expect(term.validFrom == S.month(2026, 10))
        #expect(term.averageFrom == S.month(2026, 8))
        #expect(changes.parts.map(\.id) == [gas.id])
    }

    @Test func reactivatingWithNewAmountRestartsAverage() throws {
        let gasTerms = [
            S.partTerm(gas, from: S.month(2026, 7), amount: 80, averageFrom: S.month(2026, 8)),
            S.partTerm(gas, from: S.month(2026, 9), amount: 80, averageFrom: S.month(2026, 9), isActive: false)
        ]
        var draft = editCondominio(condominioSnapshot(gasTerms: gasTerms))
        draft.addPart()
        draft.parts[2].name = "Gás"
        draft.parts[2].amount = 90

        let term = try #require(draft.buildParts(today: S.today).terms.first)

        #expect(term.partID == gas.id)
        #expect(term.isActive)
        #expect(term.amount == 90)
        #expect(term.averageFrom == S.month(2026, 11))
    }

    @Test func partValidationMessages() {
        var draft = editCondominio(condominioSnapshot())
        draft.estimatedAmount = nil
        #expect(draft.validationMessage == nil)
        draft.parts[1].name = "  "
        #expect(draft.validationMessage == "Dê um nome para cada parte.")
        draft.parts[1].name = " taxa"
        #expect(draft.validationMessage == "Cada parte precisa de um nome diferente.")
        draft.parts[1].name = "Água"
        draft.parts[2].amount = 0
        #expect(draft.validationMessage == "Informe o valor de cada parte.")
        draft.parts[2].amount = nil
        #expect(draft.validationMessage == "Informe o valor de cada parte.")
    }

    @Test func spendingDraftIgnoresParts() throws {
        var draft = ExpenseDraft(today: S.today)
        draft.kind = .spending
        draft.name = "Mercado"
        draft.dayOfMonth = 15
        draft.addPart()
        #expect(draft.validationMessage == "Informe um valor maior que zero.")
        draft.estimatedAmount = 600
        #expect(draft.validationMessage == nil)

        let (expense, built) = draft.build(today: S.today)
        let term = try #require(built)

        #expect(expense.kind == .spending)
        #expect(term.dayOfMonth == 1)
        #expect(term.estimatedAmount == 600)
        #expect(draft.buildParts(today: S.today) == ExpensePartChanges(parts: [], terms: []))
    }
}
