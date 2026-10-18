import Foundation
import Testing
@testable import Financas

struct ExpenseBillDraftTests {
    typealias S = ExpenseSamples

    private func occurrence(_ expense: Expense, bills: [ExpenseBill] = []) -> ExpenseOccurrence {
        let snapshot = ExpenseSnapshot(expenses: S.snapshot.expenses, terms: S.snapshot.terms, bills: bills)
        return ExpenseSchedule.occurrence(of: expense, in: S.month(2026, 10), snapshot: snapshot, today: S.today)!
    }

    @Test func opensInBillModeWithoutBill() {
        let draft = ExpenseBillDraft(occurrence: occurrence(S.luz), today: S.today)
        #expect(draft.mode == .bill)
        #expect(draft.billAmount == 180)
        #expect(draft.paidAmount == 180)
        #expect(draft.paidOn == S.today)
    }

    @Test func fixedExpenseOpensInPaymentModeWithRegisteredAmount() {
        var luz = S.luz
        luz.isFixed = true
        let snapshot = ExpenseSnapshot(expenses: [luz], terms: S.snapshot.terms, bills: [])
        let fixed = ExpenseSchedule.occurrence(of: luz, in: S.month(2026, 10), snapshot: snapshot, today: S.today)!
        let draft = ExpenseBillDraft(occurrence: fixed, today: S.today)
        #expect(draft.mode == .payment)
        #expect(draft.paidAmount == 180)
    }

    @Test func opensInPaymentModeWithBill() {
        let bill = S.bill(S.luz, S.month(2026, 10), 210, due: S.day(2026, 10, 20))
        let draft = ExpenseBillDraft(occurrence: occurrence(S.luz, bills: [bill]), today: S.today)
        #expect(draft.mode == .payment)
        #expect(draft.billAmount == 210)
        #expect(draft.billDueDate == S.day(2026, 10, 20))
    }

    @Test func opensInPaymentModeWhenPaid() {
        let paid = S.paid(S.luz, S.month(2026, 10), 190, on: S.day(2026, 10, 14))
        let draft = ExpenseBillDraft(occurrence: occurrence(S.luz, bills: [paid]), today: S.today)
        #expect(draft.mode == .payment)
        #expect(draft.paidAmount == 190)
        #expect(draft.paidOn == S.day(2026, 10, 14))
    }

    @Test func explicitModeWins() {
        let bill = S.bill(S.luz, S.month(2026, 10), 210, due: S.day(2026, 10, 20))
        let draft = ExpenseBillDraft(occurrence: occurrence(S.luz, bills: [bill]), today: S.today, mode: .bill)
        #expect(draft.mode == .bill)
    }

    @Test func paymentDefaultsToBillAmount() {
        let bill = S.bill(S.luz, S.month(2026, 10), 210, due: S.day(2026, 10, 20))
        let draft = ExpenseBillDraft(occurrence: occurrence(S.luz, bills: [bill]), today: S.today)
        #expect(draft.paidAmount == 210)
    }

    @Test func paymentDefaultsToEstimateWithoutBill() {
        let draft = ExpenseBillDraft(occurrence: occurrence(S.internet), today: S.today)
        #expect(draft.paidAmount == 180)
    }

    @Test func savingPaymentKeepsBillAndReusesID() {
        let bill = S.bill(S.luz, S.month(2026, 10), 210, due: S.day(2026, 10, 20))
        let target = occurrence(S.luz, bills: [bill])
        var draft = ExpenseBillDraft(occurrence: target, today: S.today)
        draft.paidAmount = 205

        let saved = draft.paymentSaved(for: target)

        #expect(saved.id == bill.id)
        #expect(saved.billAmount == 210)
        #expect(saved.billDueDate == S.day(2026, 10, 20))
        #expect(saved.paidAmount == 205)
        #expect(saved.paidOn == S.today)
    }

    @Test func savingBillWithoutExistingCreatesNew() {
        let target = occurrence(S.luz)
        var draft = ExpenseBillDraft(occurrence: target, today: S.today)
        draft.billAmount = 199

        let saved = draft.billSaved(for: target)

        #expect(saved.expenseID == S.luz.id)
        #expect(saved.month == S.month(2026, 10))
        #expect(saved.billAmount == 199)
        #expect(saved.billDueDate == target.dueDate)
        #expect(saved.paidAmount == nil)
    }

    @Test func removingPaymentKeepsBill() {
        let both = ExpenseBill(id: UUID(), expenseID: S.luz.id, month: S.month(2026, 10), billAmount: 210, billDueDate: S.day(2026, 10, 20), paidOn: S.day(2026, 10, 18), paidAmount: 210)
        let target = occurrence(S.luz, bills: [both])
        let draft = ExpenseBillDraft(occurrence: target, today: S.today)

        let remaining = draft.paymentRemoved(for: target)

        #expect(remaining?.id == both.id)
        #expect(remaining?.billAmount == 210)
        #expect(remaining?.paidAmount == nil)
        #expect(remaining?.paidOn == nil)
    }

    @Test func removingLastRecordReturnsNil() {
        let paid = S.paid(S.luz, S.month(2026, 10), 190, on: S.day(2026, 10, 14))
        let target = occurrence(S.luz, bills: [paid])
        let draft = ExpenseBillDraft(occurrence: target, today: S.today)
        #expect(draft.paymentRemoved(for: target) == nil)

        let bill = S.bill(S.luz, S.month(2026, 10), 210, due: S.day(2026, 10, 20))
        let billTarget = occurrence(S.luz, bills: [bill])
        #expect(draft.billRemoved(for: billTarget) == nil)
    }

    private let taxa = S.part(S.condominio, "Taxa", position: 0)
    private let agua = S.part(S.condominio, "Água", position: 1)
    private let gas = S.part(S.condominio, "Gás", position: 2)

    private func partsSnapshot(taxaFixed: Bool = true, aguaFixed: Bool = false, gasFixed: Bool = false, bills: [ExpenseBill] = []) -> ExpenseSnapshot {
        ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: bills,
            parts: [taxa, agua, gas],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 7), amount: 820, isFixed: taxaFixed),
                S.partTerm(agua, from: S.month(2026, 7), amount: 110, isFixed: aguaFixed),
                S.partTerm(gas, from: S.month(2026, 7), amount: 80, isFixed: gasFixed)
            ]
        )
    }

    private func partsOccurrence(_ snapshot: ExpenseSnapshot) -> ExpenseOccurrence {
        ExpenseSchedule.occurrence(of: S.condominio, in: S.month(2026, 10), snapshot: snapshot, today: S.today)!
    }

    @Test func paymentWithPartsSumsParts() {
        let target = partsOccurrence(partsSnapshot())
        let draft = ExpenseBillDraft(occurrence: target, today: S.today, mode: .payment)

        let saved = draft.paymentSaved(for: target)

        #expect(saved.paidParts == [taxa.id: 820, agua.id: 110, gas.id: 80])
        #expect(saved.paidAmount == 1010)
    }

    @Test func billWithPartsKeepsPartsAndTotal() {
        let target = partsOccurrence(partsSnapshot())
        var draft = ExpenseBillDraft(occurrence: target, today: S.today, mode: .bill)
        draft.parts[1].amount = 130

        let saved = draft.billSaved(for: target)

        #expect(saved.billParts == [taxa.id: 820, agua.id: 130, gas.id: 80])
        #expect(saved.billAmount == 1030)
        #expect(draft.partsTotal == 1030)
    }

    @Test func partsStartFromBillWhenPaying() {
        let registered = ExpenseBill(
            id: UUID(), expenseID: S.condominio.id, month: S.month(2026, 10),
            billAmount: 1010, billDueDate: S.day(2026, 10, 20),
            billParts: [taxa.id: 820, agua.id: 130, gas.id: 80]
        )
        let draft = ExpenseBillDraft(occurrence: partsOccurrence(partsSnapshot(bills: [registered])), today: S.today)

        #expect(draft.mode == .payment)
        #expect(draft.parts.first { $0.id == agua.id }?.amount == 130)
    }

    @Test func billModeKeepsBillPartsOnPaidOccurrence() {
        let paid = ExpenseBill(
            id: UUID(), expenseID: S.condominio.id, month: S.month(2026, 10),
            billAmount: 1010, billDueDate: S.day(2026, 10, 20), paidOn: S.day(2026, 10, 14), paidAmount: 1012,
            billParts: [taxa.id: 820, agua.id: 110, gas.id: 80],
            paidParts: [taxa.id: 820, agua.id: 112, gas.id: 80]
        )
        let target = partsOccurrence(partsSnapshot(bills: [paid]))
        var draft = ExpenseBillDraft(occurrence: target, today: S.today)

        #expect(draft.parts.first { $0.id == agua.id }?.amount == 112)
        draft.mode = .bill
        #expect(draft.parts.first { $0.id == agua.id }?.amount == 110)
        #expect(draft.partsTotal == 1010)

        let saved = draft.billSaved(for: target)
        #expect(saved.billParts?[agua.id] == 110)
        #expect(saved.billAmount == 1010)
        #expect(saved.paidParts?[agua.id] == 112)
    }

    @Test func partsStartFromPaidWhenEditing() {
        let paid = ExpenseBill(
            id: UUID(), expenseID: S.condominio.id, month: S.month(2026, 10),
            billAmount: 1010, paidOn: S.day(2026, 10, 14), paidAmount: 1020,
            billParts: [taxa.id: 820, agua.id: 110, gas.id: 80],
            paidParts: [taxa.id: 820, agua.id: 120, gas.id: 80]
        )
        let draft = ExpenseBillDraft(occurrence: partsOccurrence(partsSnapshot(bills: [paid])), today: S.today)

        #expect(draft.parts.first { $0.id == agua.id }?.amount == 120)
    }

    @Test func allFixedPartsOpenPayment() {
        let fixed = ExpenseBillDraft(occurrence: partsOccurrence(partsSnapshot(aguaFixed: true, gasFixed: true)), today: S.today)
        let varying = ExpenseBillDraft(occurrence: partsOccurrence(partsSnapshot()), today: S.today)

        #expect(fixed.mode == .payment)
        #expect(varying.mode == .bill)
    }

    @Test func removingPaymentClearsPaidParts() {
        let both = ExpenseBill(
            id: UUID(), expenseID: S.condominio.id, month: S.month(2026, 10),
            billAmount: 1010, billDueDate: S.day(2026, 10, 20), paidOn: S.day(2026, 10, 14), paidAmount: 1010,
            billParts: [taxa.id: 820, agua.id: 110, gas.id: 80],
            paidParts: [taxa.id: 820, agua.id: 110, gas.id: 80]
        )
        let target = partsOccurrence(partsSnapshot(bills: [both]))
        let draft = ExpenseBillDraft(occurrence: target, today: S.today)

        let remaining = draft.paymentRemoved(for: target)

        #expect(remaining?.paidParts == nil)
        #expect(remaining?.billParts == both.billParts)
        #expect(draft.billRemoved(for: target)?.billParts == nil)
    }
}
