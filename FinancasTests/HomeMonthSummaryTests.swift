import Foundation
import Testing
@testable import Financas

struct HomeMonthSummaryTests {
    typealias S = IncomeSamples

    private let october20 = S.day(2026, 10, 20)

    private func snapshot(fixedPaidOn: CalendarDay = S.day(2026, 10, 1)) -> IncomeSnapshot {
        var snapshot = S.snapshot
        snapshot.receipts = [
            S.receipt(S.fixed, S.month(2026, 10), amount: S.money("13020.04"), on: fixedPaidOn),
            S.receipt(S.hourly, S.month(2026, 10), amount: 14400, on: S.day(2026, 10, 16)),
        ]
        return snapshot
    }

    private func summary(_ month: YearMonth, _ snapshot: IncomeSnapshot, expenses: ExpenseSnapshot = .empty, today: CalendarDay? = nil) -> HomeMonthSummary {
        HomeMonthSummary.make(month: month, snapshot: snapshot, expenses: expenses, today: today ?? october20)
    }

    private func double(_ text: String) -> Double {
        NSDecimalNumber(decimal: S.money(text)).doubleValue
    }

    @Test func septemberIsEmpty() {
        let result = summary(S.month(2026, 9), snapshot())
        #expect(result.balance == 0)
        #expect(result.entries.isEmpty)
        #expect(result.points.map(\.day) == [1, 30])
        #expect(result.points.map(\.balance) == [0, 0])
    }

    @Test func octoberSumsAndOrders() {
        let result = summary(S.month(2026, 10), snapshot())
        #expect(result.balance == S.money("27420.04"))
        #expect(result.entries.map(\.title) == ["Por hora · setembro", "Fixa"])
        #expect(result.entries.map(\.kind) == [.income, .income])
        #expect(result.points.map(\.day) == [1, 1, 16, 20])
        #expect(result.points.map(\.balance) == [0, double("13020.04"), double("27420.04"), double("27420.04")])
    }

    @Test func novemberStartsFromZero() {
        let result = summary(S.month(2026, 11), snapshot())
        #expect(result.balance == 0)
        #expect(result.entries.isEmpty)
        #expect(result.points.map(\.day) == [1, 30])
        #expect(result.points.map(\.balance) == [0, 0])
    }

    @Test func paidInNovemberCountsInNovember() {
        let data = snapshot(fixedPaidOn: S.day(2026, 11, 3))
        let october = summary(S.month(2026, 10), data, today: S.day(2026, 11, 5))
        let november = summary(S.month(2026, 11), data, today: S.day(2026, 11, 5))
        #expect(october.balance == 14400)
        #expect(october.entries.map(\.kind) == [.income])
        #expect(november.balance == S.money("13020.04"))
        #expect(november.entries.first?.date == S.day(2026, 11, 3))
        #expect(november.points.map(\.day) == [1, 3, 5])
        #expect(november.points.map(\.balance) == [0, double("13020.04"), double("13020.04")])
    }

    @Test func ignoresReceiptOfDeletedIncome() {
        var data = snapshot()
        data.receipts.append(IncomeReceipt(id: UUID(), incomeID: UUID(), month: S.month(2026, 10), receivedOn: S.day(2026, 10, 5), amount: 999))
        let result = summary(S.month(2026, 10), data)
        #expect(result.balance == S.money("27420.04"))
        #expect(result.entries.count == 2)
    }

    private func paidSnapshot(_ bills: [ExpenseBill]) -> ExpenseSnapshot {
        var data = ExpenseSamples.snapshot
        data.bills = bills
        return data
    }

    @Test func balanceSubtractsPaymentsInMonth() {
        let expenses = paidSnapshot([ExpenseSamples.paid(ExpenseSamples.condominio, S.month(2026, 10), 1150, on: S.day(2026, 10, 9))])
        let result = summary(S.month(2026, 10), snapshot(), expenses: expenses)
        #expect(result.balance == S.money("26270.04"))
    }

    @Test func paymentCountsInMonthOfPaymentDate() {
        let expenses = paidSnapshot([ExpenseSamples.paid(ExpenseSamples.luz, S.month(2026, 9), 200, on: S.day(2026, 10, 2))])
        let september = summary(S.month(2026, 9), snapshot(), expenses: expenses)
        let october = summary(S.month(2026, 10), snapshot(), expenses: expenses)
        #expect(september.balance == 0)
        #expect(october.balance == S.money("27220.04"))
    }

    @Test func chartGoesDownOnPaymentDay() {
        let expenses = paidSnapshot([ExpenseSamples.paid(ExpenseSamples.condominio, S.month(2026, 10), 1150, on: S.day(2026, 10, 9))])
        let result = summary(S.month(2026, 10), snapshot(), expenses: expenses)
        #expect(result.points.map(\.day) == [1, 1, 9, 16, 20])
        #expect(result.points.map(\.balance) == [0, double("13020.04"), double("11870.04"), double("26270.04"), double("26270.04")])
    }

    @Test func entriesMixAndSortByDate() {
        let expenses = paidSnapshot([ExpenseSamples.paid(ExpenseSamples.condominio, S.month(2026, 10), 1150, on: S.day(2026, 10, 9))])
        let result = summary(S.month(2026, 10), snapshot(), expenses: expenses)
        #expect(result.entries.map(\.title) == ["Por hora · setembro", "Condomínio", "Fixa"])
        #expect(result.entries.map(\.kind) == [.income, .expense, .income])
        #expect(result.entries[1].amount == 1150)
        #expect(result.entries[1].date == S.day(2026, 10, 9))
    }

    @Test func ignoresPaymentOfDeletedExpense() {
        let ghost = ExpenseBill(id: UUID(), expenseID: UUID(), month: S.month(2026, 10), billAmount: nil, billDueDate: nil, paidOn: S.day(2026, 10, 5), paidAmount: 999)
        let result = summary(S.month(2026, 10), snapshot(), expenses: paidSnapshot([ghost]))
        #expect(result.balance == S.money("27420.04"))
        #expect(result.entries.count == 2)
    }

    @Test func chartDomainPadsAroundValues() {
        let result = summary(S.month(2026, 10), snapshot())
        let high = double("27420.04")
        #expect(result.chartDomain.lowerBound == -high * 0.05)
        #expect(result.chartDomain.upperBound == high * 1.05)
        #expect(summary(S.month(2026, 9), snapshot()).chartDomain == 0...1)
    }
}
