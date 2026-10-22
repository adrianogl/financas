import Foundation
import Testing
@testable import Financas

struct CardCommitmentTests {
    private func plan(_ name: String, lastMonth: YearMonth, amount: Decimal = 100) -> InstallmentPlan {
        InstallmentPlan(
            cardAccountID: CardSamples.c6.id,
            name: name,
            purchaseDate: CardSamples.day(2026, 1, 1),
            installmentAmount: amount,
            totalInstallments: 4,
            lastSeenNumber: 4,
            lastSeenMonth: lastMonth
        )
    }

    private func fixed(_ amount: Decimal) -> FixedCharge {
        FixedCharge(
            recurrence: CardRecurrence(id: UUID(), cardAccountID: CardSamples.c6.id, merchantKey: "x", status: .confirmed, endedOn: nil),
            name: "Fixo",
            amount: amount,
            lastChargedOn: CardSamples.day(2026, 10, 1),
            isStale: false
        )
    }

    @Test func monthsStackInstallmentsAndFixed() {
        let nov = YearMonth(year: 2026, month: 11)
        let result = CardCommitment.months(
            plans: [plan("PlayStation", lastMonth: nov, amount: 112.47)],
            fixed: [fixed(999.90)],
            from: nov,
            count: 12
        )
        #expect(result.count == 12)
        #expect(result[0].month == nov)
        #expect(result[0].installments == 112.47)
        #expect(result[0].fixed == 999.90)
        #expect(result[0].total == Decimal(string: "1112.37"))
        #expect(result[1].month == YearMonth(year: 2026, month: 12))
        #expect(result[1].installments == 0)
        #expect(result[1].fixed == 999.90)
    }

    @Test func endingIsLastMonthWithinNextThree() {
        let plans = [
            plan("Fev", lastMonth: YearMonth(year: 2027, month: 2)),
            plan("Jan", lastMonth: YearMonth(year: 2027, month: 1)),
            plan("Nov", lastMonth: YearMonth(year: 2026, month: 11)),
            plan("Out", lastMonth: YearMonth(year: 2026, month: 10)),
            plan("Set", lastMonth: YearMonth(year: 2026, month: 9))
        ]
        let result = CardCommitment.ending(plans, today: CardSamples.today)
        #expect(result.map(\.name) == ["Out", "Nov", "Jan"])
    }
}
