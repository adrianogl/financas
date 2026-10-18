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

    private func snapshot(_ bills: [ExpenseBill] = [], extraTerms: [ExpensePartTerm] = []) -> ExpenseSnapshot {
        ExpenseSnapshot(
            expenses: [S.condominio],
            terms: [S.condominioTerm],
            bills: bills,
            parts: [gas, taxa, agua],
            partTerms: partTerms + extraTerms
        )
    }

    private func paid(_ month: YearMonth, _ parts: [UUID: Decimal]) -> ExpenseBill {
        ExpenseBill(
            id: UUID(),
            expenseID: S.condominio.id,
            month: month,
            paidOn: month.day(10),
            paidAmount: parts.values.reduce(0, +),
            paidParts: parts
        )
    }

    private func value(of part: ExpensePart, in month: YearMonth, _ snapshot: ExpenseSnapshot) -> ExpensePartValue? {
        ExpensePartSchedule.values(of: S.condominio, in: month, snapshot: snapshot).first { $0.part == part }
    }

    @Test func fixedPartUsesRegisteredAmount() throws {
        let bills = (7...9).map { paid(S.month(2026, $0), [taxa.id: 900]) }
        let october = try #require(value(of: taxa, in: S.month(2026, 10), snapshot(bills)))
        #expect(october.amount == 820)
        #expect(october.origin == .fixed)
        #expect(october.isFixed)
    }

    @Test func variablePartAveragesLastThreePaid() throws {
        let bills = [
            paid(S.month(2026, 7), [agua.id: 70]),
            paid(S.month(2026, 8), [agua.id: 80]),
            paid(S.month(2026, 9), [agua.id: 90])
        ]
        let october = try #require(value(of: agua, in: S.month(2026, 10), snapshot(bills)))
        #expect(october.amount == 80)
        #expect(october.origin == .average(months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]))
        #expect(!october.isFixed)
    }

    @Test func variablePartWithTwoPaidUsesRegistered() throws {
        let bills = [
            paid(S.month(2026, 8), [agua.id: 80]),
            paid(S.month(2026, 9), [agua.id: 90])
        ]
        let october = try #require(value(of: agua, in: S.month(2026, 10), snapshot(bills)))
        #expect(october.amount == 85)
        #expect(october.origin == .estimated)
    }

    @Test func paidAndBillOverrideEstimate() throws {
        var bill = ExpenseBill(id: UUID(), expenseID: S.condominio.id, month: S.month(2026, 10), billAmount: 1010, billParts: [agua.id: 110])
        let launched = try #require(value(of: agua, in: S.month(2026, 10), snapshot([bill])))
        #expect(launched.amount == 110)
        #expect(launched.origin == .bill)

        bill.paidAmount = 1012
        bill.paidParts = [agua.id: 112]
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
        #expect(ExpensePartSchedule.values(of: S.condominio, in: S.month(2026, 11), snapshot: base).map(\.amount) == [820, 85])
    }

    @Test func reactivatedPartKeepsAverageHistory() throws {
        let inactive = S.partTerm(gas, from: S.month(2026, 11), amount: 80, averageFrom: S.month(2026, 7), isActive: false)
        let active = S.partTerm(gas, from: S.month(2026, 12), amount: 80, averageFrom: S.month(2026, 7))
        let bills = [
            paid(S.month(2026, 7), [gas.id: 60]),
            paid(S.month(2026, 8), [gas.id: 70]),
            paid(S.month(2026, 9), [gas.id: 95])
        ]
        let base = snapshot(bills, extraTerms: [inactive, active])
        #expect(ExpensePartSchedule.activeParts(of: S.condominio, in: S.month(2026, 11), snapshot: base) == [taxa, agua])
        let december = try #require(value(of: gas, in: S.month(2026, 12), base))
        #expect(december.amount == 75)
        #expect(december.origin == .average(months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]))
    }

    @Test func termIsNilBeforeFirstValidFrom() {
        #expect(ExpensePartSchedule.term(for: agua, in: S.month(2026, 6), snapshot: snapshot()) == nil)
        #expect(ExpensePartSchedule.values(of: S.condominio, in: S.month(2026, 6), snapshot: snapshot()).isEmpty)
    }

    @Test func changeComparesRegisteredMonths() {
        let october = ExpenseBill(id: UUID(), expenseID: S.condominio.id, month: S.month(2026, 10), billAmount: 1010, billParts: [agua.id: 110])
        let september = paid(S.month(2026, 9), [agua.id: 80])
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
