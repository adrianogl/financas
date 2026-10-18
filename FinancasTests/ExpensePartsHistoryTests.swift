import Foundation
import Testing
@testable import Financas

struct ExpensePartsHistoryTests {
    typealias S = ExpenseSamples

    private let condominio = Expense(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!,
        name: "Condomínio",
        startMonth: ExpenseSamples.month(2026, 7)
    )

    private func history(
        parts: [ExpensePart],
        partTerms: [ExpensePartTerm],
        partBills: [ExpensePartBill] = [],
        bills: [ExpenseBill] = [],
        month: YearMonth = ExpenseSamples.month(2026, 10)
    ) throws -> ExpensePartsHistory {
        let snapshot = ExpenseSnapshot(
            expenses: [condominio],
            terms: [S.term(condominio, from: S.month(2026, 7), day: 10, estimated: 900)],
            bills: bills,
            parts: parts,
            partTerms: partTerms,
            partBills: partBills
        )
        let occurrence = try #require(ExpenseSchedule.occurrence(of: condominio, in: month, snapshot: snapshot, today: S.today))
        return ExpensePartsHistory.make(occurrence: occurrence, snapshot: snapshot)
    }

    @Test func rowsWithPartsAndIncrease() throws {
        let taxa = S.part(condominio, "Taxa", position: 0)
        let agua = S.part(condominio, "Água", position: 1)
        let months = [S.month(2026, 7), S.month(2026, 8), S.month(2026, 9), S.month(2026, 10)]
        let water: [Decimal] = [82, 78, 80, 110]
        let bills = zip(months, water).flatMap { month, amount in
            [S.partBill(taxa, month, paid: 820), S.partBill(agua, month, paid: amount)]
        }

        let result = try history(
            parts: [agua, taxa],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 7), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 7), amount: 80)
            ],
            partBills: bills
        )

        #expect(result.columns == [taxa, agua])
        #expect(result.rows.map(\.month) == months.reversed())
        let october = try #require(result.rows.first)
        #expect(october.amounts == [taxa.id: 820, agua.id: 110])
        #expect(october.total == 930)
        #expect(october.increased == [agua.id])
        #expect(result.rows[1].increased.contains(agua.id))
    }

    @Test func monthBeforePartsShowsOnlyTotal() throws {
        let taxa = S.part(condominio, "Taxa", position: 0)
        let result = try history(
            parts: [taxa],
            partTerms: [S.partTerm(taxa, from: S.month(2026, 9), amount: 820, isFixed: true)],
            partBills: [S.partBill(taxa, S.month(2026, 9), paid: 820)],
            bills: [S.paid(condominio, S.month(2026, 8), 900, on: S.day(2026, 8, 10))]
        )

        let august = try #require(result.rows.first { $0.month == S.month(2026, 8) })
        #expect(august.amounts.isEmpty)
        #expect(august.total == 900)
        let september = try #require(result.rows.first { $0.month == S.month(2026, 9) })
        #expect(september.amounts == [taxa.id: 820])
        #expect(september.total == 820)
    }

    @Test func currentMonthWithoutRecordUsesCalculatedValues() throws {
        let taxa = S.part(condominio, "Taxa", position: 0)
        let agua = S.part(condominio, "Água", position: 1)
        let result = try history(
            parts: [taxa, agua],
            partTerms: [
                S.partTerm(taxa, from: S.month(2026, 10), amount: 820, isFixed: true),
                S.partTerm(agua, from: S.month(2026, 10), amount: 80)
            ]
        )

        let october = try #require(result.rows.first)
        #expect(october.month == S.month(2026, 10))
        #expect(october.amounts == [taxa.id: 820, agua.id: 80])
        #expect(october.total == 900)
        #expect(october.increased.isEmpty)
        #expect(result.rows.dropFirst().allSatisfy { $0.amounts.isEmpty && $0.total == nil })
    }
}
