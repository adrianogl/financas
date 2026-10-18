import Foundation
import Testing
@testable import Financas

struct ExpensePartBillDraftTests {
    typealias S = ExpenseSamples

    private let taxa = S.part(S.condominio, "Taxa", position: 0)
    private let agua = S.part(S.condominio, "Água", position: 1)

    private func values(_ partBills: [ExpensePartBill] = []) -> [ExpensePartValue] {
        let snapshot = ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: [],
            parts: [taxa, agua],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 10), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 10), amount: 85, day: 15)
            ],
            partBills: partBills
        )
        return ExpensePartSchedule.values(of: S.condominio, in: S.month(2026, 10), snapshot: snapshot, today: S.today)
    }

    private func value(_ part: ExpensePart, _ partBills: [ExpensePartBill] = []) throws -> ExpensePartValue {
        try #require(values(partBills).first { $0.part.id == part.id })
    }

    @Test func partDraftDefaultsAndSaves() throws {
        #expect(ExpensePartBillDraft(value: try value(taxa), today: S.today).mode == .payment)
        #expect(ExpensePartBillDraft(value: try value(agua), today: S.today).mode == .bill)

        let launched = S.partBill(agua, S.month(2026, 10), bill: 92, due: S.day(2026, 10, 18))
        var draft = ExpensePartBillDraft(value: try value(agua, [launched]), today: S.today)
        #expect(draft.mode == .payment)
        #expect(draft.paidAmount == 92)
        draft.paidAmount = 93
        draft.paidOn = S.day(2026, 10, 16)

        let saved = draft.paymentSaved()

        #expect(saved.id == launched.id)
        #expect(saved.partID == agua.id)
        #expect(saved.month == S.month(2026, 10))
        #expect(saved.paidAmount == 93)
        #expect(saved.paidOn == S.day(2026, 10, 16))
        #expect(saved.billAmount == 92)
        #expect(saved.billDueDate == S.day(2026, 10, 18))
    }

    @Test func partBillSavedUsesOwnDueDate() throws {
        var draft = ExpensePartBillDraft(value: try value(agua), today: S.today)
        #expect(draft.billAmount == 85)
        #expect(draft.billDueDate == S.day(2026, 10, 15))
        draft.billAmount = 97
        draft.billDueDate = S.day(2026, 10, 22)

        let saved = draft.billSaved()

        #expect(saved.partID == agua.id)
        #expect(saved.billAmount == 97)
        #expect(saved.billDueDate == S.day(2026, 10, 22))
        #expect(saved.paidAmount == nil)
    }

    @Test func removingKeepsTheOtherRecord() throws {
        let both = ExpensePartBill(
            id: UUID(), partID: agua.id, month: S.month(2026, 10),
            billAmount: 92, billDueDate: S.day(2026, 10, 18), paidOn: S.day(2026, 10, 16), paidAmount: 92
        )
        let draft = ExpensePartBillDraft(value: try value(agua, [both]), today: S.today)

        #expect(draft.paymentRemoved()?.billAmount == 92)
        #expect(draft.paymentRemoved()?.paidAmount == nil)
        #expect(draft.billRemoved()?.paidAmount == 92)
        #expect(draft.billRemoved()?.billAmount == nil)

        let paidOnly = S.partBill(agua, S.month(2026, 10), paid: 85, on: S.day(2026, 10, 16))
        #expect(ExpensePartBillDraft(value: try value(agua, [paidOnly]), today: S.today).paymentRemoved() == nil)
    }
}
