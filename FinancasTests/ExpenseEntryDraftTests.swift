import Foundation
import Testing
@testable import Financas

struct ExpenseEntryDraftTests {
    typealias S = ExpenseSamples

    private var abastecimento: Expense {
        Expense(id: UUID(), name: "Abastecimento", startMonth: S.month(2026, 8), endMonth: S.month(2026, 10), kind: .spending)
    }

    private func draft(amount: Decimal? = 50, on day: CalendarDay) -> ExpenseEntryDraft {
        var draft = ExpenseEntryDraft(expense: abastecimento, month: S.month(2026, 10), today: S.today)
        draft.amount = amount
        draft.spentOn = day
        return draft
    }

    @Test func defaultDateIsTodayInCurrentMonth() {
        let draft = ExpenseEntryDraft(expense: abastecimento, month: S.month(2026, 10), today: S.today)
        #expect(draft.spentOn == S.day(2026, 10, 17))
        #expect(draft.isNew)
    }

    @Test func defaultDateIsLastDayInPastMonth() {
        let draft = ExpenseEntryDraft(expense: abastecimento, month: S.month(2026, 9), today: S.today)
        #expect(draft.spentOn == S.day(2026, 9, 30))
    }

    @Test func validEntryHasNoMessage() {
        #expect(draft(on: S.day(2026, 10, 17)).validationMessage == nil)
        #expect(draft(on: S.day(2026, 8, 1)).validationMessage == nil)
    }

    @Test func futureDateIsInvalid() {
        #expect(draft(on: S.day(2026, 10, 18)).validationMessage == ExpenseConstants.entryDateMessage)
    }

    @Test func dateBeforeStartIsInvalid() {
        #expect(draft(on: S.day(2026, 7, 31)).validationMessage == ExpenseConstants.entryDateMessage)
    }

    @Test func dateAfterEndIsInvalid() {
        var ended = abastecimento
        ended.endMonth = S.month(2026, 9)
        var draft = ExpenseEntryDraft(expense: ended, month: S.month(2026, 9), today: S.today)
        draft.amount = 10
        draft.spentOn = S.day(2026, 10, 1)
        #expect(draft.validationMessage == ExpenseConstants.entryDateMessage)
    }

    @Test func missingOrZeroAmountIsInvalid() {
        #expect(draft(amount: nil, on: S.today).validationMessage == ExpenseConstants.entryAmountMessage)
        #expect(draft(amount: 0, on: S.today).validationMessage == ExpenseConstants.entryAmountMessage)
    }

    @Test func editingKeepsID() {
        let entry = ExpenseEntry(id: UUID(), expenseID: abastecimento.id, spentOn: S.day(2026, 9, 3), amount: 80)
        var draft = ExpenseEntryDraft(entry: entry, expense: abastecimento, today: S.today)
        draft.amount = 95
        let built = draft.build()
        #expect(!draft.isNew)
        #expect(built.id == entry.id)
        #expect(built.amount == 95)
        #expect(built.spentOn == S.day(2026, 9, 3))
    }
}
