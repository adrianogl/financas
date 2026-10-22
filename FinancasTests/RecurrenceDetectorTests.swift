import Foundation
import Testing
@testable import Financas

struct RecurrenceDetectorTests {
    private let today = CardSamples.today

    private func decision(_ status: CardRecurrenceStatus, key: String, ended: CalendarDay? = nil) -> CardRecurrence {
        CardRecurrence(id: UUID(), cardAccountID: CardSamples.c6.id, merchantKey: key, status: status, endedOn: ended)
    }

    private func monthly(_ description: String, _ amount: Decimal, months: [Int]) -> [CardTransaction] {
        months.map { CardSamples.tx(CardSamples.c6, 2026, $0, 10, amount, description) }
    }

    @Test func wellhubSixMonthsIsCandidate() {
        let transactions = monthly("Wellhub", 183.30, months: [5, 6, 7, 8, 9, 10])
        let result = RecurrenceDetector.candidates(from: transactions, decisions: [], today: today)
        #expect(result.count == 1)
        #expect(result.first?.monthCount == 6)
        #expect(result.first?.typicalAmount == 183.30)
        #expect(result.first?.name == "Wellhub")
        #expect(result.first?.chargedAfterEnd == false)
    }

    @Test func amountsOverTenPercentAreNotCandidate() {
        let transactions = [
            CardSamples.tx(CardSamples.c6, 2026, 8, 5, 100, "Loja X"),
            CardSamples.tx(CardSamples.c6, 2026, 9, 5, 100, "Loja X"),
            CardSamples.tx(CardSamples.c6, 2026, 10, 5, 120, "Loja X")
        ]
        #expect(RecurrenceDetector.candidates(from: transactions, decisions: [], today: today).isEmpty)
    }

    @Test func twoMonthsIsNotCandidate() {
        let transactions = monthly("Wellhub", 183.30, months: [9, 10])
        #expect(RecurrenceDetector.candidates(from: transactions, decisions: [], today: today).isEmpty)
    }

    @Test func chargesOlderThanTwelveMonthsAreIgnored() {
        let transactions = [
            CardSamples.tx(CardSamples.c6, 2025, 9, 22, 50, "Antiga"),
            CardSamples.tx(CardSamples.c6, 2025, 10, 21, 50, "Antiga"),
            CardSamples.tx(CardSamples.c6, 2025, 10, 22, 50, "Antiga"),
            CardSamples.tx(CardSamples.c6, 2025, 11, 22, 50, "Antiga")
        ]
        let result = RecurrenceDetector.candidates(from: transactions, decisions: [], today: today)
        #expect(result.isEmpty)
        let withWindow = transactions + [CardSamples.tx(CardSamples.c6, 2025, 12, 22, 50, "Antiga")]
        #expect(RecurrenceDetector.candidates(from: withWindow, decisions: [], today: today).first?.monthCount == 3)
    }

    @Test func installmentsPendingAndCreditsAreIgnored() {
        let installments = (7...10).map {
            CardSamples.tx(CardSamples.c6, 2026, $0, 10, 90, "Loja Y", installment: ($0 - 6, 10), purchase: CardSamples.day(2026, 7, 10))
        }
        let pending = [
            CardSamples.tx(CardSamples.c6, 2026, 8, 10, 30, "Loja Z", pending: true),
            CardSamples.tx(CardSamples.c6, 2026, 9, 10, 30, "Loja Z", pending: true),
            CardSamples.tx(CardSamples.c6, 2026, 10, 10, 30, "Loja Z", pending: true)
        ]
        let credits = (8...10).map {
            CardSamples.tx(CardSamples.c6, 2026, $0, 10, 30, "Estorno", type: .credit)
        }
        let result = RecurrenceDetector.candidates(from: installments + pending + credits, decisions: [], today: today)
        #expect(result.isEmpty)
    }

    @Test func dismissedNeverReturns() {
        let transactions = [
            CardSamples.tx(CardSamples.c6, 2026, 8, 3, 51.00, "Gelateria"),
            CardSamples.tx(CardSamples.c6, 2026, 9, 3, 50.50, "Gelateria"),
            CardSamples.tx(CardSamples.c6, 2026, 10, 3, 52.00, "Gelateria")
        ]
        let key = MerchantKey.make("Gelateria")
        #expect(RecurrenceDetector.candidates(from: transactions, decisions: [], today: today).count == 1)
        #expect(RecurrenceDetector.candidates(from: transactions, decisions: [decision(.dismissed, key: key)], today: today).isEmpty)
    }

    @Test func confirmedIsNotCandidate() {
        let transactions = monthly("Wellhub", 183.30, months: [8, 9, 10])
        let decisions = [decision(.confirmed, key: MerchantKey.make("Wellhub"))]
        #expect(RecurrenceDetector.candidates(from: transactions, decisions: decisions, today: today).isEmpty)
    }

    @Test func endedReturnsOnlyAfterNewCharge() {
        let key = MerchantKey.make("Netflix")
        let ended = [decision(.ended, key: key, ended: CardSamples.day(2026, 9, 1))]
        var transactions = [
            CardSamples.tx(CardSamples.c6, 2026, 6, 10, 55.90, "Netflix"),
            CardSamples.tx(CardSamples.c6, 2026, 7, 10, 55.90, "Netflix"),
            CardSamples.tx(CardSamples.c6, 2026, 8, 10, 55.90, "Netflix")
        ]
        #expect(RecurrenceDetector.candidates(from: transactions, decisions: ended, today: today).isEmpty)
        transactions.append(CardSamples.tx(CardSamples.c6, 2026, 10, 10, 55.90, "Netflix"))
        let result = RecurrenceDetector.candidates(from: transactions, decisions: ended, today: today)
        #expect(result.count == 1)
        #expect(result.first?.chargedAfterEnd == true)
    }

    @Test func idCombinesCardAndMerchantKey() {
        let candidate = RecurrenceCandidate(
            cardAccountID: CardSamples.c6.id,
            merchantKey: "wellhub",
            name: "Wellhub",
            monthCount: 3,
            typicalAmount: 10,
            chargedAfterEnd: false
        )
        #expect(candidate.id == "\(CardSamples.c6.id)|wellhub")
    }
}
