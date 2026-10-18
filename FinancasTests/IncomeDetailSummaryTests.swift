import Foundation
import Testing
@testable import Financas

struct IncomeDetailSummaryTests {
    private let today = IncomeSamples.day(2026, 10, 17)

    private func salary(start: YearMonth = IncomeSamples.month(2026, 7)) -> Income {
        Income(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
            name: "Salário",
            kind: .fixed,
            dayOfMonth: 5,
            startMonth: start
        )
    }

    private func snapshot(_ income: Income, receipts: [IncomeReceipt] = []) -> IncomeSnapshot {
        IncomeSnapshot(
            incomes: [income],
            amounts: [
                IncomeAmount(id: UUID(), incomeID: income.id, amount: 6800, validFrom: IncomeSamples.month(2026, 7)),
                IncomeAmount(id: UUID(), incomeID: income.id, amount: 7150, validFrom: IncomeSamples.month(2026, 11))
            ],
            receipts: receipts
        )
    }

    private func summary(_ income: Income, in month: YearMonth, receipts: [IncomeReceipt] = []) throws -> IncomeDetailSummary {
        let snapshot = snapshot(income, receipts: receipts)
        let occurrence = try #require(IncomeSchedule.occurrence(of: income, in: month, snapshot: snapshot, today: today))
        return IncomeDetailSummary.make(occurrence: occurrence, snapshot: snapshot, today: today)
    }

    @Test func ruleAndCurrent() throws {
        let result = try summary(salary(), in: IncomeSamples.month(2026, 10))
        #expect(result.rule == "Receita fixa · todo dia 5")
        #expect(result.current?.amount == 6800)
        #expect(result.current?.validFrom == IncomeSamples.month(2026, 7))
    }

    @Test func historyMarksMissingMonths() throws {
        let income = salary()
        let receipts = [
            IncomeSamples.receipt(income, IncomeSamples.month(2026, 7), amount: 6800),
            IncomeSamples.receipt(income, IncomeSamples.month(2026, 9), amount: 7150)
        ]
        let result = try summary(income, in: IncomeSamples.month(2026, 10), receipts: receipts)
        #expect(result.history == [
            DetailHistoryEntry(month: IncomeSamples.month(2026, 9), amount: 7150),
            DetailHistoryEntry(month: IncomeSamples.month(2026, 8), amount: nil),
            DetailHistoryEntry(month: IncomeSamples.month(2026, 7), amount: 6800)
        ])
    }

    @Test func historySkipsMonthsBeforeStart() throws {
        let result = try summary(salary(start: IncomeSamples.month(2026, 9)), in: IncomeSamples.month(2026, 10))
        #expect(result.history.map(\.month) == [IncomeSamples.month(2026, 9)])
    }

    @Test func historyCountsFromOccurrenceMonth() throws {
        let result = try summary(salary(), in: IncomeSamples.month(2026, 9))
        #expect(result.history.map(\.month) == [IncomeSamples.month(2026, 8), IncomeSamples.month(2026, 7)])
    }

    @Test func oneOffHasNoCurrentNorHistory() throws {
        let income = Income(
            id: UUID(), name: "Bônus", kind: .oneOff,
            oneOffDate: IncomeSamples.day(2026, 10, 12), oneOffAmount: 500
        )
        let result = try summary(income, in: IncomeSamples.month(2026, 10))
        #expect(result.rule == "Receita avulsa · seg, 12 out")
        #expect(result.current == nil)
        #expect(result.history.isEmpty)
    }
}
