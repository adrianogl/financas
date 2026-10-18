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
}
