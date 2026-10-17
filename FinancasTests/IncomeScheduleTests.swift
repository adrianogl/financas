import Foundation
import Testing
@testable import Financas

struct IncomeScheduleTests {
    typealias S = IncomeSamples

    private func occurrence(_ income: Income, _ month: YearMonth, snapshot: IncomeSnapshot = S.snapshot, today: CalendarDay = S.today) -> IncomeOccurrence? {
        IncomeSchedule.occurrence(of: income, in: month, snapshot: snapshot, today: today)
    }

    @Test func fixedInNovember() throws {
        let item = try #require(occurrence(S.fixed, S.month(2026, 11)))
        #expect(item.dueDate == S.day(2026, 11, 3))
        #expect(item.expectedAmount == S.money("13020.04"))
        #expect(item.status == .pending)
    }

    @Test func hourlyInNovemberRefersToOctober() throws {
        let item = try #require(occurrence(S.hourly, S.month(2026, 11)))
        #expect(item.referenceMonth == S.month(2026, 10))
        #expect(item.businessDays == 21)
        #expect(item.hourlyRate == 90)
        #expect(item.expectedAmount == 15120)
        #expect(item.dueDate == S.day(2026, 11, 16))
    }

    @Test func hourlyInOctoberRefersToSeptember() throws {
        let item = try #require(occurrence(S.hourly, S.month(2026, 10)))
        #expect(item.referenceMonth == S.month(2026, 9))
        #expect(item.businessDays == 21)
        #expect(item.expectedAmount == 15120)
        #expect(item.dueDate == S.day(2026, 10, 15))
        #expect(item.status == .overdue)
    }

    @Test func dueTodayIsPending() throws {
        let item = try #require(occurrence(S.hourly, S.month(2026, 10), today: S.day(2026, 10, 15)))
        #expect(item.status == .pending)
    }

    @Test func receiptMarksReceived() throws {
        var snapshot = S.snapshot
        snapshot.receipts = [S.receipt(S.fixed, S.month(2026, 10), amount: S.money("13020.04"))]
        let item = try #require(occurrence(S.fixed, S.month(2026, 10), snapshot: snapshot))
        #expect(item.status == .received)
        #expect(item.receipt == snapshot.receipts.first)
    }

    @Test func rateChangeKeepsPreviousMonths() throws {
        var snapshot = S.snapshot
        snapshot.amounts.append(IncomeAmount(id: UUID(), incomeID: S.hourly.id, amount: 100, validFrom: S.month(2026, 11)))
        let november = try #require(occurrence(S.hourly, S.month(2026, 11), snapshot: snapshot))
        let december = try #require(occurrence(S.hourly, S.month(2026, 12), snapshot: snapshot))
        #expect(november.expectedAmount == 15120)
        #expect(december.businessDays == 19)
        #expect(december.expectedAmount == 15200)
    }

    @Test func januaryRefersToDecemberOfPreviousYear() throws {
        var snapshot = S.snapshot
        snapshot.amounts.append(IncomeAmount(id: UUID(), incomeID: S.hourly.id, amount: 100, validFrom: S.month(2027, 1)))
        let item = try #require(occurrence(S.hourly, S.month(2027, 1), snapshot: snapshot))
        #expect(item.referenceMonth == S.month(2026, 12))
        #expect(item.hourlyRate == 90)
        #expect(item.businessDays == BusinessCalendar.businessDays(in: S.month(2026, 12)))
    }

    @Test func skipsMonthWithoutAmount() {
        var snapshot = S.snapshot
        snapshot.amounts = [IncomeAmount(id: UUID(), incomeID: S.hourly.id, amount: 90, validFrom: S.month(2026, 11))]
        #expect(occurrence(S.hourly, S.month(2026, 11), snapshot: snapshot) == nil)
        #expect(occurrence(S.hourly, S.month(2026, 12), snapshot: snapshot) != nil)
    }

    @Test func respectsStartAndEnd() {
        var ending = S.fixed
        ending.endMonth = S.month(2026, 12)
        let snapshot = IncomeSnapshot(incomes: [ending], amounts: [S.fixedAmount], receipts: [])
        #expect(occurrence(ending, S.month(2026, 9), snapshot: snapshot) == nil)
        #expect(occurrence(ending, S.month(2026, 12), snapshot: snapshot) != nil)
        #expect(occurrence(ending, S.month(2027, 1), snapshot: snapshot) == nil)
    }

    @Test func day31InFebruary() throws {
        var last = S.fixed
        last.dayOfMonth = 31
        let snapshot = IncomeSnapshot(incomes: [last], amounts: [S.fixedAmount], receipts: [])
        let item = try #require(occurrence(last, S.month(2027, 2), snapshot: snapshot))
        #expect(item.dueDate == S.day(2027, 3, 1))
    }

    @Test func oneOffOnItsDate() throws {
        let oneOff = Income(id: UUID(), name: "Bônus", kind: .oneOff, oneOffDate: S.day(2026, 11, 20), oneOffAmount: 500)
        let snapshot = IncomeSnapshot(incomes: [oneOff], amounts: [], receipts: [])
        let item = try #require(occurrence(oneOff, S.month(2026, 11), snapshot: snapshot))
        #expect(item.dueDate == S.day(2026, 11, 20))
        #expect(item.expectedAmount == 500)
        #expect(occurrence(oneOff, S.month(2026, 10), snapshot: snapshot) == nil)
        #expect(occurrence(oneOff, S.month(2026, 12), snapshot: snapshot) == nil)
    }

    @Test func occurrencesAreSortedByDueDate() {
        let items = IncomeSchedule.occurrences(in: S.month(2026, 11), snapshot: S.snapshot, today: S.today)
        #expect(items.map(\.income.id) == [S.fixed.id, S.hourly.id])
    }

    @Test func overdueFromSeptemberCarriesToOctober() {
        var hourly = S.hourly
        hourly.startMonth = S.month(2026, 9)
        let rate = IncomeAmount(id: UUID(), incomeID: hourly.id, amount: 90, validFrom: S.month(2026, 8))
        let snapshot = IncomeSnapshot(incomes: [hourly], amounts: [rate], receipts: [])

        let overdue = IncomeSchedule.overdue(before: S.month(2026, 10), snapshot: snapshot, today: S.today)
        #expect(overdue.map(\.month) == [S.month(2026, 9)])
        #expect(overdue.first?.referenceMonth == S.month(2026, 8))

        let summary = IncomeSchedule.summary(for: S.month(2026, 10), snapshot: snapshot, today: S.today)
        let august = Decimal(BusinessCalendar.businessDays(in: S.month(2026, 8))) * 8 * 90
        #expect(summary.remaining == august + 15120)
        #expect(summary.overdueCount == 2)
    }

    @Test func summaryOctober() {
        var snapshot = S.snapshot
        snapshot.receipts = [S.receipt(S.fixed, S.month(2026, 10), amount: S.money("13020.04"))]
        let summary = IncomeSchedule.summary(for: S.month(2026, 10), snapshot: snapshot, today: S.today)
        #expect(summary.received == S.money("13020.04"))
        #expect(summary.remaining == 15120)
        #expect(summary.expected == S.money("28140.04"))
        #expect(summary.overdueCount == 1)
        #expect(summary.next?.income.id == S.fixed.id)
        #expect(summary.next?.dueDate == S.day(2026, 11, 3))
    }

    @Test func summaryUsesReceivedAmount() {
        var snapshot = S.snapshot
        snapshot.receipts = [S.receipt(S.fixed, S.month(2026, 10), amount: 13000)]
        let summary = IncomeSchedule.summary(for: S.month(2026, 10), snapshot: snapshot, today: S.today)
        #expect(summary.received == 13000)
        #expect(summary.expected == 28120)
    }

    @Test func pastMonthHasNoCarryOver() {
        var hourly = S.hourly
        hourly.startMonth = S.month(2026, 8)
        let rate = IncomeAmount(id: UUID(), incomeID: hourly.id, amount: 90, validFrom: S.month(2026, 7))
        let snapshot = IncomeSnapshot(incomes: [hourly], amounts: [rate], receipts: [])
        let summary = IncomeSchedule.summary(for: S.month(2026, 9), snapshot: snapshot, today: S.today)
        let august = Decimal(BusinessCalendar.businessDays(in: S.month(2026, 8))) * 8 * 90
        #expect(summary.remaining == august)
        #expect(summary.overdueCount == 1)
    }
}
