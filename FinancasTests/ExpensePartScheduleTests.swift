import Foundation
import Testing
@testable import Financas

struct ExpensePartScheduleTests {
    typealias S = ExpenseSamples

    private let taxa = S.part(S.condominio, "Taxa", position: 0)
    private let agua = S.part(S.condominio, "Água", position: 1)
    private let gas = S.part(S.condominio, "Gás", position: 2)

    private var partTerms: [ExpensePartTerm] {
        [
            S.partTerm(taxa, from: S.month(2026, 7), amount: 820, isFixed: true),
            S.partTerm(agua, from: S.month(2026, 7), amount: 85),
            S.partTerm(gas, from: S.month(2026, 7), amount: 80)
        ]
    }

    private func snapshot(_ partBills: [ExpensePartBill] = [], extraTerms: [ExpensePartTerm] = [], terms: [ExpensePartTerm]? = nil) -> ExpenseSnapshot {
        ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: [],
            parts: [gas, taxa, agua],
            partTerms: (terms ?? partTerms) + extraTerms,
            partBills: partBills
        )
    }

    private func paid(_ month: YearMonth, _ part: ExpensePart, _ amount: Decimal) -> ExpensePartBill {
        S.partBill(part, month, paid: amount)
    }

    private func value(of part: ExpensePart, in month: YearMonth, _ snapshot: ExpenseSnapshot, today: CalendarDay = S.today) -> ExpensePartValue? {
        ExpensePartSchedule.values(of: S.condominio, in: month, snapshot: snapshot, today: today).first { $0.part == part }
    }

    private var ownDayTerms: [ExpensePartTerm] {
        [
            S.partTerm(taxa, from: S.month(2026, 7), amount: 820, isFixed: true),
            S.partTerm(agua, from: S.month(2026, 7), amount: 85, day: 15),
            S.partTerm(gas, from: S.month(2026, 7), amount: 80, day: 26)
        ]
    }

    @Test func partDueDateUsesOwnDay() throws {
        let base = snapshot(terms: ownDayTerms)
        let water = try #require(value(of: agua, in: S.month(2026, 10), base))
        let fee = try #require(value(of: taxa, in: S.month(2026, 10), base))
        #expect(water.dueDate == S.day(2026, 10, 15))
        #expect(fee.dueDate == S.day(2026, 10, 13))
        #expect(water.month == S.month(2026, 10))
        #expect(water.id == "\(agua.id)-2026-10")
    }

    @Test func partBillOverridesDueDateAndAmount() throws {
        let launched = S.partBill(agua, S.month(2026, 10), bill: 110, due: S.day(2026, 10, 20))
        let water = try #require(value(of: agua, in: S.month(2026, 10), snapshot([launched], terms: ownDayTerms)))
        #expect(water.amount == 110)
        #expect(water.origin == .bill)
        #expect(water.dueDate == S.day(2026, 10, 20))
        #expect(water.bill == launched)
    }

    @Test func partStatusPaidOverdueAndPending() throws {
        let fee = paid(S.month(2026, 10), taxa, 820)
        let base = snapshot([fee], terms: ownDayTerms)
        let values = ExpensePartSchedule.values(of: S.condominio, in: S.month(2026, 10), snapshot: base, today: S.today)
        #expect(values.map(\.part) == [taxa, agua, gas])
        #expect(values.map(\.status) == [.paid, .overdue, .pending])
    }

    @Test func averageReadsPartBills() throws {
        let bills = [
            paid(S.month(2026, 7), agua, 100),
            paid(S.month(2026, 8), agua, 110),
            paid(S.month(2026, 9), agua, 121),
            paid(S.month(2026, 9), gas, 500)
        ]
        let water = try #require(value(of: agua, in: S.month(2026, 10), snapshot(bills)))
        #expect(water.amount == S.money("110.33"))
        #expect(water.origin == .average(months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]))
    }

    @Test func fixedPartUsesRegisteredAmount() throws {
        let bills = (7...9).map { paid(S.month(2026, $0), taxa, 900) }
        let october = try #require(value(of: taxa, in: S.month(2026, 10), snapshot(bills)))
        #expect(october.amount == 820)
        #expect(october.origin == .fixed)
        #expect(october.isFixed)
    }

    @Test func variablePartAveragesLastThreePaid() throws {
        let bills = [
            paid(S.month(2026, 7), agua, 70),
            paid(S.month(2026, 8), agua, 80),
            paid(S.month(2026, 9), agua, 90)
        ]
        let october = try #require(value(of: agua, in: S.month(2026, 10), snapshot(bills)))
        #expect(october.amount == 80)
        #expect(october.origin == .average(months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]))
        #expect(!october.isFixed)
    }

    @Test func variablePartWithTwoPaidUsesRegistered() throws {
        let bills = [
            paid(S.month(2026, 8), agua, 80),
            paid(S.month(2026, 9), agua, 90)
        ]
        let october = try #require(value(of: agua, in: S.month(2026, 10), snapshot(bills)))
        #expect(october.amount == 85)
        #expect(october.origin == .estimated)
    }

    @Test func paidAndBillOverrideEstimate() throws {
        var bill = S.partBill(agua, S.month(2026, 10), bill: 110)
        let launched = try #require(value(of: agua, in: S.month(2026, 10), snapshot([bill])))
        #expect(launched.amount == 110)
        #expect(launched.origin == .bill)

        bill.paidAmount = 112
        bill.paidOn = S.day(2026, 10, 14)
        let settled = try #require(value(of: agua, in: S.month(2026, 10), snapshot([bill])))
        #expect(settled.amount == 112)
        #expect(settled.origin == .paid)
    }

    @Test func occurrenceAmountIsSumOfParts() throws {
        let october = try #require(ExpenseSchedule.occurrence(of: S.condominio, in: S.month(2026, 10), snapshot: snapshot(), today: S.today))
        #expect(october.amount == 985)
        #expect(october.estimate == .parts(985))
        #expect(october.parts.map(\.part) == [taxa, agua, gas])
    }

    @Test func expenseWithoutPartsHasNoPartValues() throws {
        let base = ExpenseSnapshot(expenses: [S.condominio], terms: [S.condominioTerm], bills: [])
        let october = try #require(ExpenseSchedule.occurrence(of: S.condominio, in: S.month(2026, 10), snapshot: base, today: S.today))
        #expect(october.parts.isEmpty)
        #expect(october.estimate == .manual(1150))
    }

    @Test func inactivePartLeavesFromItsMonth() {
        let inactive = S.partTerm(gas, from: S.month(2026, 11), amount: 80, averageFrom: S.month(2026, 7), isActive: false)
        let base = snapshot(extraTerms: [inactive])
        #expect(ExpensePartSchedule.activeParts(of: S.condominio, in: S.month(2026, 10), snapshot: base) == [taxa, agua, gas])
        #expect(ExpensePartSchedule.activeParts(of: S.condominio, in: S.month(2026, 11), snapshot: base) == [taxa, agua])
        #expect(ExpensePartSchedule.values(of: S.condominio, in: S.month(2026, 11), snapshot: base, today: S.today).map(\.amount) == [820, 85])
    }

    @Test func reactivatedPartKeepsAverageHistory() throws {
        let inactive = S.partTerm(gas, from: S.month(2026, 11), amount: 80, averageFrom: S.month(2026, 7), isActive: false)
        let active = S.partTerm(gas, from: S.month(2026, 12), amount: 80, averageFrom: S.month(2026, 7))
        let bills = [
            paid(S.month(2026, 7), gas, 60),
            paid(S.month(2026, 8), gas, 70),
            paid(S.month(2026, 9), gas, 95)
        ]
        let base = snapshot(bills, extraTerms: [inactive, active])
        #expect(ExpensePartSchedule.activeParts(of: S.condominio, in: S.month(2026, 11), snapshot: base) == [taxa, agua])
        let december = try #require(value(of: gas, in: S.month(2026, 12), base))
        #expect(december.amount == 75)
        #expect(december.origin == .average(months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]))
    }

    @Test func termIsNilBeforeFirstValidFrom() {
        #expect(ExpensePartSchedule.term(for: agua, in: S.month(2026, 6), snapshot: snapshot()) == nil)
        #expect(ExpensePartSchedule.values(of: S.condominio, in: S.month(2026, 6), snapshot: snapshot(), today: S.today).isEmpty)
    }

    @Test func changeComparesRegisteredMonths() {
        let october = S.partBill(agua, S.month(2026, 10), bill: 110)
        let september = paid(S.month(2026, 9), agua, 80)
        #expect(ExpensePartSchedule.change(of: agua, in: S.month(2026, 10), snapshot: snapshot([september, october])) == 30)
        #expect(ExpensePartSchedule.change(of: agua, in: S.month(2026, 10), snapshot: snapshot([october])) == nil)
        #expect(ExpensePartSchedule.change(of: agua, in: S.month(2026, 10), snapshot: snapshot([september])) == nil)
    }

    @Test func spendingIsNotAnOccurrence() {
        var mercado = Expense(id: UUID(), name: "Mercado", startMonth: S.month(2026, 8))
        mercado.kind = .spending
        let term = S.term(mercado, from: S.month(2026, 8), day: 5, estimated: 900)
        let base = ExpenseSnapshot(expenses: [mercado], terms: [term], bills: [])
        let october = S.month(2026, 10)
        #expect(ExpenseSchedule.occurrences(in: october, snapshot: base, today: S.today).isEmpty)
        #expect(ExpenseSchedule.carried(into: october, snapshot: base, today: S.today).isEmpty)
        #expect(ExpenseSchedule.overdue(before: october, snapshot: base, today: S.today).isEmpty)
        #expect(ExpenseSchedule.summary(for: october, snapshot: base, today: S.today).overdueCount == 0)
    }
}
