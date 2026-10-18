import Foundation
import Testing
@testable import Financas

struct ExpenseScheduleTests {
    typealias S = ExpenseSamples

    private func snapshot(_ bills: [ExpenseBill] = [], terms: [ExpenseTerm]? = nil, expenses: [Expense]? = nil) -> ExpenseSnapshot {
        ExpenseSnapshot(expenses: expenses ?? S.snapshot.expenses, terms: terms ?? S.snapshot.terms, bills: bills)
    }

    private func occurrence(_ expense: Expense, _ month: YearMonth, _ snapshot: ExpenseSnapshot, today: CalendarDay = S.today) -> ExpenseOccurrence? {
        ExpenseSchedule.occurrence(of: expense, in: month, snapshot: snapshot, today: today)
    }

    private func luzPaid(_ amounts: [(Int, Int, String)]) -> [ExpenseBill] {
        amounts.map { S.paid(S.luz, S.month($0.0, $0.1), S.money($0.2), on: S.day($0.0, $0.1, 13)) }
    }

    @Test func dueDateMovesToNextBusinessDay() throws {
        let december = try #require(occurrence(S.luz, S.month(2026, 12), snapshot()))
        #expect(december.dueDate == S.day(2026, 12, 14))
        let october = try #require(occurrence(S.condominio, S.month(2026, 10), snapshot()))
        #expect(october.dueDate == S.day(2026, 10, 13))
    }

    @Test func day31InFebruary() throws {
        let term = S.term(S.luz, from: S.month(2026, 7), day: 31, estimated: 180)
        let february = try #require(occurrence(S.luz, S.month(2027, 2), snapshot(terms: [term])))
        #expect(february.dueDate == S.day(2027, 3, 1))
    }

    @Test func billDueDateReplacesCalculatedOnlyThatMonth() throws {
        let bills = [S.bill(S.luz, S.month(2026, 10), 212, due: S.day(2026, 10, 17))]
        let october = try #require(occurrence(S.luz, S.month(2026, 10), snapshot(bills)))
        let november = try #require(occurrence(S.luz, S.month(2026, 11), snapshot(bills)))
        #expect(october.dueDate == S.day(2026, 10, 17))
        #expect(november.dueDate == S.day(2026, 11, 13))
    }

    @Test func fixedExpenseKeepsRegisteredAmountAfterThreePaidMonths() throws {
        var luz = S.luz
        luz.isFixed = true
        let bills = luzPaid([(2026, 7, "196.40"), (2026, 8, "201.10"), (2026, 9, "188.00")])
        let base = snapshot(bills, expenses: [luz])
        #expect(ExpenseSchedule.estimate(for: luz, in: S.month(2026, 10), snapshot: base) == .fixed(180))
        let october = try #require(occurrence(luz, S.month(2026, 10), base))
        #expect(october.amount == 180)
    }

    @Test func estimateIsManualWithTwoPaidMonths() {
        let bills = luzPaid([(2026, 7, "196.40"), (2026, 8, "201.10")])
        #expect(ExpenseSchedule.estimate(for: S.luz, in: S.month(2026, 10), snapshot: snapshot(bills)) == .manual(180))
    }

    @Test func estimateIsAverageWithThreePaidMonths() {
        let bills = luzPaid([(2026, 7, "196.40"), (2026, 8, "201.10"), (2026, 9, "219.80")])
        let estimate = ExpenseSchedule.estimate(for: S.luz, in: S.month(2026, 10), snapshot: snapshot(bills))
        #expect(estimate == .average(amount: S.money("205.77"), months: [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9)]))
    }

    @Test func averageUsesThreeMostRecent() {
        let bills = luzPaid([(2026, 7, "100"), (2026, 8, "100"), (2026, 9, "200"), (2026, 10, "300"), (2026, 11, "400")])
        let estimate = ExpenseSchedule.estimate(for: S.luz, in: S.month(2026, 12), snapshot: snapshot(bills))
        #expect(estimate == .average(amount: 300, months: [S.month(2026, 9), S.month(2026, 10), S.month(2026, 11)]))
    }

    @Test func averageIgnoresMonthsBeforeAverageFrom() {
        let edited = S.term(S.luz, from: S.month(2026, 10), day: 13, estimated: 250, averageFrom: S.month(2026, 11))
        let terms = [S.luzTerm, edited]
        let early = luzPaid([(2026, 7, "100"), (2026, 8, "100"), (2026, 9, "100")])
        let base = snapshot(early, terms: terms)
        #expect(ExpenseSchedule.estimate(for: S.luz, in: S.month(2026, 10), snapshot: base) == .manual(250))
        #expect(ExpenseSchedule.estimate(for: S.luz, in: S.month(2026, 11), snapshot: base) == .manual(250))

        let later = early + luzPaid([(2026, 11, "300"), (2026, 12, "300"), (2027, 1, "300")])
        let february = ExpenseSchedule.estimate(for: S.luz, in: S.month(2027, 2), snapshot: snapshot(later, terms: terms))
        #expect(february == .average(amount: 300, months: [S.month(2026, 11), S.month(2026, 12), S.month(2027, 1)]))
    }

    @Test func termBeforeEditKeepsOldEstimateAndDay() throws {
        let edited = S.term(S.luz, from: S.month(2026, 10), day: 20, estimated: 250)
        let data = snapshot(terms: [S.luzTerm, edited])
        let september = try #require(occurrence(S.luz, S.month(2026, 9), data))
        let october = try #require(occurrence(S.luz, S.month(2026, 10), data))
        #expect(september.dueDate == S.day(2026, 9, 14))
        #expect(september.estimate == .manual(180))
        #expect(october.dueDate == S.day(2026, 10, 20))
        #expect(october.estimate == .manual(250))
    }

    @Test func amountPrefersPaidThenBillThenEstimate() throws {
        let plain = try #require(occurrence(S.luz, S.month(2026, 10), snapshot()))
        #expect(plain.amount == 180)
        #expect(!plain.hasBill)

        let billed = try #require(occurrence(S.luz, S.month(2026, 10), snapshot([S.bill(S.luz, S.month(2026, 10), S.money("212.30"), due: S.day(2026, 10, 13))])))
        #expect(billed.amount == S.money("212.30"))
        #expect(billed.hasBill)

        var payment = S.bill(S.luz, S.month(2026, 10), S.money("212.30"), due: S.day(2026, 10, 13))
        payment.paidAmount = S.money("210.00")
        payment.paidOn = S.day(2026, 10, 14)
        let paid = try #require(occurrence(S.luz, S.month(2026, 10), snapshot([payment])))
        #expect(paid.amount == S.money("210.00"))
        #expect(paid.status == .paid)
    }

    @Test func statusAndOverdueCarry() throws {
        let septemberUnpaid = try #require(occurrence(S.luz, S.month(2026, 9), snapshot(luzPaid([(2026, 7, "100"), (2026, 8, "100")]))))
        #expect(septemberUnpaid.status == .overdue)

        let open = snapshot(luzPaid([(2026, 7, "100"), (2026, 8, "100")]))
        #expect(ExpenseSchedule.carried(into: S.month(2026, 10), snapshot: open, today: S.today).map(\.expense) == [S.luz])

        let settled = snapshot(luzPaid([(2026, 7, "100"), (2026, 8, "100"), (2026, 9, "100")]))
        #expect(ExpenseSchedule.carried(into: S.month(2026, 10), snapshot: settled, today: S.today).isEmpty)
    }

    @Test func endedExpenseStillCarriesUnpaidMonth() {
        var ended = S.luz
        ended.endMonth = S.month(2026, 9)
        let data = snapshot(luzPaid([(2026, 7, "100"), (2026, 8, "100")]), expenses: [ended])
        let carried = ExpenseSchedule.carried(into: S.month(2026, 10), snapshot: data, today: S.today)
        #expect(carried.map(\.month) == [S.month(2026, 9)])
    }

    @Test func billDueInPreviousMonthIsCarried() throws {
        let bills = [S.bill(S.luz, S.month(2026, 11), 200, due: S.day(2026, 10, 30))]
        let data = snapshot(bills + luzPaid([(2026, 7, "100"), (2026, 8, "100"), (2026, 9, "100"), (2026, 10, "100")]))
        let today = S.day(2026, 10, 31)
        let carried = ExpenseSchedule.carried(into: S.month(2026, 10), snapshot: data, today: today)
        let item = try #require(carried.first { $0.month == S.month(2026, 11) })
        #expect(item.status == .overdue)
        #expect(ExpenseSchedule.overdue(before: S.month(2026, 10), snapshot: data, today: today).contains { $0.id == item.id })
    }

    @Test func previousMonthDueThisMonthStaysVisibleUntilOverdue() throws {
        let aluguel = Expense(id: UUID(), name: "Aluguel", startMonth: S.month(2026, 10))
        let term = S.term(aluguel, from: S.month(2026, 10), day: 31, estimated: 900)
        let data = ExpenseSnapshot(expenses: [aluguel], terms: [term], bills: [])
        let october = S.month(2026, 10)
        let november = S.month(2026, 11)

        let dueDay = S.day(2026, 11, 3)
        let onDueDay = ExpenseSchedule.carried(into: november, snapshot: data, today: dueDay)
        #expect(onDueDay.map(\.month) == [october])
        #expect(onDueDay.first?.status == .pending)
        #expect(onDueDay.first?.dueDate == dueDay)

        let firstDay = ExpenseSchedule.summary(for: november, snapshot: data, today: S.day(2026, 11, 1))
        #expect(firstDay.remaining == 1800)
        #expect(firstDay.next?.month == october)

        let afterDue = ExpenseSchedule.carried(into: november, snapshot: data, today: S.day(2026, 11, 4))
        #expect(afterDue.map(\.month) == [october])
        #expect(afterDue.first?.status == .overdue)
    }

    @Test func summaryForOctober() {
        let bills = luzPaid([(2026, 7, "196.40"), (2026, 8, "201.10"), (2026, 9, "219.80")])
            + [S.bill(S.luz, S.month(2026, 10), S.money("212.30"), due: S.day(2026, 10, 13)),
               S.paid(S.condominio, S.month(2026, 10), 1150, on: S.day(2026, 10, 9))]
        let summary = ExpenseSchedule.summary(for: S.month(2026, 10), snapshot: snapshot(bills), today: S.today)
        #expect(summary.paid == 1150)
        #expect(summary.remaining == S.money("392.30"))
        #expect(summary.expected == S.money("1542.30"))
        #expect(summary.overdueCount == 1)
        #expect(summary.next?.expense == S.internet)
    }
    private let taxa = S.part(S.condominio, "Taxa", position: 0)
    private let agua = S.part(S.condominio, "Água", position: 1)
    private let gas = S.part(S.condominio, "Gás", position: 2)

    private func partsSnapshot(_ partBills: [ExpensePartBill], expense: Expense = S.condominio) -> ExpenseSnapshot {
        ExpenseSnapshot(
            expenses: [expense],
            terms: [S.condominioTerm],
            bills: [],
            parts: [taxa, agua, gas],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 7), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 7), amount: 85, day: 15),
                S.partTerm(gas, from: S.month(2026, 7), amount: 80, day: 26)
            ],
            partBills: partBills
        )
    }

    @Test func occurrenceAggregatesPartStatus() throws {
        let october = S.month(2026, 10)
        let fee = S.partBill(taxa, october, paid: 820, on: S.day(2026, 10, 9))
        let open = try #require(occurrence(S.condominio, october, partsSnapshot([fee])))
        #expect(open.status == .overdue)
        #expect(open.isPartiallyPaid)
        #expect(open.amount == 985)
        #expect(open.remaining == 165)
        #expect(open.dueDate == S.day(2026, 10, 15))

        let all = [fee, S.partBill(agua, october, paid: 90, on: S.day(2026, 10, 16)), S.partBill(gas, october, paid: 80, on: S.day(2026, 10, 16))]
        let settled = try #require(occurrence(S.condominio, october, partsSnapshot(all)))
        #expect(settled.status == .paid)
        #expect(!settled.isPartiallyPaid)
        #expect(settled.amount == 990)
        #expect(settled.remaining == 0)
        #expect(settled.dueDate == S.day(2026, 10, 26))

        let pending = try #require(occurrence(S.condominio, october, partsSnapshot([]), today: S.day(2026, 10, 1)))
        #expect(pending.status == .pending)
        #expect(!pending.isPartiallyPaid)
        #expect(pending.remaining == 985)
        #expect(pending.dueDate == S.day(2026, 10, 13))
    }

    @Test func occurrenceWithoutPartsRemaining() throws {
        let open = try #require(occurrence(S.internet, S.month(2026, 10), snapshot()))
        #expect(open.remaining == 180)
        #expect(!open.isPartiallyPaid)
        let paid = try #require(occurrence(S.internet, S.month(2026, 10), snapshot([S.paid(S.internet, S.month(2026, 10), 180, on: S.today)])))
        #expect(paid.remaining == 0)
    }

    @Test func summaryUsesRemainingAndPartPayments() {
        let fee = S.partBill(taxa, S.month(2026, 10), paid: 820, on: S.day(2026, 10, 9))
        let summary = ExpenseSchedule.summary(for: S.month(2026, 10), snapshot: partsSnapshot([fee]), today: S.today)
        #expect(summary.paid == 820)
        #expect(summary.remaining == 165)
        #expect(summary.expected == 985)
        #expect(summary.overdueCount == 1)
    }

    @Test func carriedWhileAnyPartOpen() {
        let condominio = Expense(id: S.condominio.id, name: S.condominio.name, startMonth: S.month(2026, 9))
        let september = S.month(2026, 9)
        let october = S.month(2026, 10)
        let partial = [S.partBill(taxa, september, paid: 820), S.partBill(gas, september, paid: 80)]
        let open = ExpenseSchedule.carried(into: october, snapshot: partsSnapshot(partial, expense: condominio), today: S.today)
        #expect(open.map(\.month) == [september])
        #expect(open.first?.remaining == 85)

        let settled = partial + [S.partBill(agua, september, paid: 85)]
        #expect(ExpenseSchedule.carried(into: october, snapshot: partsSnapshot(settled, expense: condominio), today: S.today).isEmpty)
    }

    private func fixedPartsSnapshot(expenseIsFixed: Bool, partsFixed: Bool) -> (Expense, ExpenseSnapshot) {
        var condominio = S.condominio
        condominio.isFixed = expenseIsFixed
        let snapshot = ExpenseSnapshot(
            expenses: [condominio],
            terms: [S.condominioTerm],
            bills: [],
            parts: [taxa, agua],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 10), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 10), amount: 85, isFixed: partsFixed)
            ]
        )
        return (condominio, snapshot)
    }

    @Test func badgeWithPartsIgnoresExpenseFixed() throws {
        let early = S.day(2026, 10, 1)
        let october = S.month(2026, 10)

        let (fixedExpense, variableParts) = fixedPartsSnapshot(expenseIsFixed: true, partsFixed: false)
        #expect(try #require(occurrence(fixedExpense, october, variableParts, today: early)).badge == .estimated)

        let (variableExpense, fixedParts) = fixedPartsSnapshot(expenseIsFixed: false, partsFixed: true)
        #expect(try #require(occurrence(variableExpense, october, fixedParts, today: early)).badge == nil)

        var launched = variableParts
        launched.partBills = [S.partBill(agua, october, bill: 90, due: S.day(2026, 10, 15))]
        #expect(try #require(occurrence(fixedExpense, october, launched, today: early)).badge == .billLaunched)
    }

    @Test func badgeKeepsStatusPriority() throws {
        let october = S.month(2026, 10)
        let fee = S.partBill(taxa, october, paid: 820, on: S.day(2026, 10, 9))
        #expect(try #require(occurrence(S.condominio, october, partsSnapshot([fee]))).badge == .overdue)
        #expect(try #require(occurrence(S.condominio, october, partsSnapshot([fee]), today: S.day(2026, 10, 10))).badge == .partiallyPaid)
        let all = [fee, S.partBill(agua, october, paid: 85), S.partBill(gas, october, paid: 80)]
        #expect(try #require(occurrence(S.condominio, october, partsSnapshot(all))).badge == nil)
    }

    @Test func badgeWithoutPartsUsesExpenseFixed() throws {
        var internet = S.internet
        #expect(try #require(occurrence(internet, S.month(2026, 10), snapshot(expenses: [internet]))).badge == .estimated)
        internet.isFixed = true
        #expect(try #require(occurrence(internet, S.month(2026, 10), snapshot(expenses: [internet]))).badge == nil)
        let launched = snapshot([S.bill(S.internet, S.month(2026, 10), 190, due: S.day(2026, 10, 26))])
        #expect(try #require(occurrence(S.internet, S.month(2026, 10), launched)).badge == .billLaunched)
    }

    @Test func amountDueShowsRemainingWhenPartiallyPaid() throws {
        let october = S.month(2026, 10)
        let fee = S.partBill(taxa, october, paid: 820, on: S.day(2026, 10, 9))
        #expect(try #require(occurrence(S.condominio, october, partsSnapshot([fee]))).amountDue == 165)
        #expect(try #require(occurrence(S.condominio, october, partsSnapshot([]))).amountDue == 985)
        #expect(try #require(occurrence(S.internet, october, snapshot())).amountDue == 180)
    }
}
