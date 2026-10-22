import Foundation
import Testing
@testable import Financas

struct InstallmentPlansTests {
    @Test func playStationIsOnePurchaseWithOneLeft() {
        let june27 = CardSamples.day(2026, 6, 27)
        let txs = [
            CardSamples.tx(CardSamples.c6, 2026, 6, 27, 112.49, "EBN *PLAYSTATION", installment: (1, 4), purchase: june27),
            CardSamples.tx(CardSamples.c6, 2026, 8, 5, 112.47, "EBN *PLAYSTATION", installment: (2, 4), purchase: june27),
            CardSamples.tx(CardSamples.c6, 2026, 9, 8, 112.47, "EBN *PLAYSTATION", installment: (3, 4), purchase: june27),
        ]
        let plans = InstallmentPlans.plans(from: txs, today: CardSamples.today)
        #expect(plans.count == 1)
        #expect(plans[0].installmentAmount == Decimal(string: "112.47"))
        #expect(plans[0].lastMonth == YearMonth(year: 2026, month: 10))
        #expect(plans[0].releasesIn == YearMonth(year: 2026, month: 11))
        #expect(plans[0].amount(in: YearMonth(year: 2026, month: 10)) == Decimal(string: "112.47"))
        #expect(plans[0].amount(in: YearMonth(year: 2026, month: 11)) == 0)
    }

    @Test func installmentMonthIsTransactionDateMonth() {
        let txs = [
            CardSamples.tx(CardSamples.c6, 2026, 4, 2, 100, "LOJA X", installment: (2, 10), purchase: CardSamples.day(2026, 3, 2)),
        ]
        let plans = InstallmentPlans.plans(from: txs, today: CardSamples.day(2026, 5, 10))
        #expect(plans.count == 1)
        #expect(plans[0].lastSeenMonth == YearMonth(year: 2026, month: 4))
        #expect(plans[0].amount(in: YearMonth(year: 2026, month: 4)) > 0)
        #expect(plans[0].amount(in: YearMonth(year: 2026, month: 5)) > 0)
        #expect(plans[0].lastMonth == YearMonth(year: 2026, month: 12))
    }

    @Test func sameInstallmentTwiceCountsOnce() {
        let purchase = CardSamples.day(2026, 9, 1)
        let txs = [
            CardSamples.tx(CardSamples.c6, 2026, 10, 3, 50, "LOJA Y", installment: (2, 10), purchase: purchase, pending: true),
            CardSamples.tx(CardSamples.c6, 2026, 10, 5, 50, "LOJA Y", installment: (2, 10), purchase: purchase),
        ]
        let plans = InstallmentPlans.plans(from: txs, today: CardSamples.today)
        #expect(plans.count == 1)
        #expect(plans[0].lastSeenNumber == 2)
    }

    @Test func creditWithInstallmentDataIsIgnored() {
        let txs = [
            CardSamples.tx(CardSamples.c6, 2026, 10, 3, 50, "ESTORNO", installment: (2, 10), purchase: CardSamples.day(2026, 9, 1), type: .credit),
        ]
        #expect(InstallmentPlans.plans(from: txs, today: CardSamples.today).isEmpty)
    }

    @Test func planDropsWhenNextInstallmentMissingTwoMonths() {
        let purchase = CardSamples.day(2026, 6, 1)
        let july = [CardSamples.tx(CardSamples.c6, 2026, 7, 5, 80, "LOJA Z", installment: (2, 10), purchase: purchase)]
        #expect(InstallmentPlans.plans(from: july, today: CardSamples.today).isEmpty)
        let august = [CardSamples.tx(CardSamples.c6, 2026, 8, 5, 80, "LOJA Z", installment: (2, 10), purchase: purchase)]
        #expect(InstallmentPlans.plans(from: august, today: CardSamples.today).count == 1)
    }
}
