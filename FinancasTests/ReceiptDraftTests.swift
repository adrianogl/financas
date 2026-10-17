import Foundation
import Testing
@testable import Financas

struct ReceiptDraftTests {
    typealias S = IncomeSamples

    private func occurrence(_ income: Income, snapshot: IncomeSnapshot = S.snapshot) throws -> IncomeOccurrence {
        try #require(IncomeSchedule.occurrence(of: income, in: S.month(2026, 10), snapshot: snapshot, today: S.today))
    }

    @Test func defaultsFromOccurrence() throws {
        let draft = ReceiptDraft(occurrence: try occurrence(S.hourly), today: S.today)
        #expect(draft.workedDays == 21)
        #expect(draft.workedHours == 168)
        #expect(draft.amount == 15120)
        #expect(draft.expectedAmount == 15120)
        #expect(draft.receivedOn == S.today)
    }

    @Test func changingDaysRecalculates() throws {
        var draft = ReceiptDraft(occurrence: try occurrence(S.hourly), today: S.today)
        draft.setWorkedDays(20)
        #expect(draft.workedHours == 160)
        #expect(draft.expectedAmount == 14400)
        #expect(draft.amount == 14400)
    }

    @Test func changingHoursRecalculates() throws {
        var draft = ReceiptDraft(occurrence: try occurrence(S.hourly), today: S.today)
        draft.setWorkedHours(170)
        #expect(draft.amount == 15300)
    }

    @Test func fixedHasNoHours() throws {
        let draft = ReceiptDraft(occurrence: try occurrence(S.fixed), today: S.today)
        #expect(draft.workedDays == nil)
        #expect(draft.workedHours == nil)
        #expect(draft.amount == S.money("13020.04"))
    }

    @Test func existingReceiptIsTheStartingPoint() throws {
        var receipt = S.receipt(S.hourly, S.month(2026, 10), amount: 14400, on: S.day(2026, 10, 15))
        receipt.workedDays = 20
        receipt.workedHours = 160
        var snapshot = S.snapshot
        snapshot.receipts = [receipt]
        let item = try occurrence(S.hourly, snapshot: snapshot)
        let draft = ReceiptDraft(occurrence: item, today: S.today)
        #expect(draft.workedDays == 20)
        #expect(draft.amount == 14400)
        #expect(draft.receivedOn == S.day(2026, 10, 15))
        #expect(draft.receipt(for: item).id == receipt.id)
    }

    @Test func buildsReceiptForOccurrenceMonth() throws {
        let item = try occurrence(S.hourly)
        let receipt = ReceiptDraft(occurrence: item, today: S.today).receipt(for: item)
        #expect(receipt.incomeID == S.hourly.id)
        #expect(receipt.month == S.month(2026, 10))
        #expect(receipt.workedHours == 168)
    }
}
