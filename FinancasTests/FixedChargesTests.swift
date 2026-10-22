import Foundation
import Testing
@testable import Financas

struct FixedChargesTests {
    private let today = CardSamples.today

    private func recurrence(_ status: CardRecurrenceStatus, _ name: String, ended: CalendarDay? = nil) -> CardRecurrence {
        CardRecurrence(id: UUID(), cardAccountID: CardSamples.c6.id, merchantKey: MerchantKey.make(name), status: status, endedOn: ended)
    }

    @Test func fixedChargeUsesLastAmountAndFlagsStale() {
        let confirmed = recurrence(.confirmed, "Spotify")
        var transactions = [
            CardSamples.tx(CardSamples.c6, 2026, 7, 6, 40.90, "Spotify"),
            CardSamples.tx(CardSamples.c6, 2026, 9, 20, 44.90, "Spotify")
        ]
        var result = FixedCharges.charges(from: transactions, recurrences: [confirmed], today: today)
        #expect(result.count == 1)
        #expect(result.first?.amount == 44.90)
        #expect(result.first?.lastChargedOn == CardSamples.day(2026, 9, 20))
        #expect(result.first?.isStale == false)

        transactions = [
            CardSamples.tx(CardSamples.c6, 2026, 7, 6, 40.90, "Spotify"),
            CardSamples.tx(CardSamples.c6, 2026, 9, 6, 44.90, "Spotify")
        ]
        result = FixedCharges.charges(from: transactions, recurrences: [confirmed], today: today)
        #expect(result.first?.amount == 44.90)
        #expect(result.first?.isStale == true)
    }

    @Test func exactlyFortyFiveDaysIsNotStale() {
        let confirmed = recurrence(.confirmed, "Spotify")
        let transactions = [CardSamples.tx(CardSamples.c6, 2026, 9, 7, 44.90, "Spotify")]
        let result = FixedCharges.charges(from: transactions, recurrences: [confirmed], today: today)
        #expect(result.first?.isStale == false)
    }

    @Test func pendingInstallmentAndCreditChargesAreIgnored() {
        let confirmed = recurrence(.confirmed, "Spotify")
        let transactions = [
            CardSamples.tx(CardSamples.c6, 2026, 8, 6, 40.90, "Spotify"),
            CardSamples.tx(CardSamples.c6, 2026, 9, 6, 99, "Spotify", pending: true),
            CardSamples.tx(CardSamples.c6, 2026, 9, 7, 99, "Spotify", type: .credit),
            CardSamples.tx(CardSamples.c6, 2026, 9, 8, 99, "Spotify", installment: (1, 3), purchase: CardSamples.day(2026, 9, 8))
        ]
        let result = FixedCharges.charges(from: transactions, recurrences: [confirmed], today: today)
        #expect(result.first?.amount == 40.90)
    }

    @Test func endedIsNotFixed() {
        let ended = recurrence(.ended, "Spotify", ended: CardSamples.day(2026, 9, 1))
        let transactions = [CardSamples.tx(CardSamples.c6, 2026, 9, 20, 44.90, "Spotify")]
        #expect(FixedCharges.charges(from: transactions, recurrences: [ended], today: today).isEmpty)
    }

    @Test func confirmedWithoutChargesIsSkipped() {
        let confirmed = recurrence(.confirmed, "Spotify")
        #expect(FixedCharges.charges(from: [], recurrences: [confirmed], today: today).isEmpty)
    }

    @Test func chargesFromOtherCardsAreIgnored() {
        let confirmed = recurrence(.confirmed, "Spotify")
        let transactions = [CardSamples.tx(CardSamples.caixa, 2026, 9, 20, 44.90, "Spotify")]
        #expect(FixedCharges.charges(from: transactions, recurrences: [confirmed], today: today).isEmpty)
    }
}
