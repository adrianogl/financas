import Foundation
import Testing
@testable import Financas

struct CardCodingTests {
    @Test func decodesTransactionRow() throws {
        let json = #"{"id":"tx1","card_account_id":"\#(CardSamples.c6.id)","date":"2026-09-08","description":"EBN *PLAYSTATION","amount":112.47,"type":"DEBIT","is_pending":false,"installment_number":3,"total_installments":4,"purchase_date":"2026-06-27"}"#
        let tx = try JSONDecoder().decode(CardTransaction.self, from: Data(json.utf8))
        #expect(tx.date == CalendarDay(year: 2026, month: 9, day: 8))
        #expect(tx.amount == Decimal(string: "112.47"))
        #expect(tx.installmentNumber == 3 && tx.totalInstallments == 4)
        #expect(tx.purchaseDate == CalendarDay(year: 2026, month: 6, day: 27))
        #expect(tx.type == .debit && !tx.isPending)
    }

    @Test func decodesConnectionWithNeedsReconnect() throws {
        let json = #"{"id":"\#(CardSamples.connection)","item_id":"item-1","status":"needs_reconnect","last_synced_at":null,"last_error":"login"}"#
        let connection = try JSONDecoder().decode(CardConnection.self, from: Data(json.utf8))
        #expect(connection.status == .needsReconnect)
        #expect(connection.itemID == "item-1")
        #expect(connection.lastSyncedAt == nil)
    }

    @Test func encodesRecurrenceWithEndedOn() throws {
        let recurrence = CardRecurrence(
            id: UUID(),
            cardAccountID: CardSamples.c6.id,
            merchantKey: "netflix",
            status: .ended,
            endedOn: CardSamples.day(2026, 10, 1)
        )
        let data = try JSONEncoder().encode(recurrence)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["status"] as? String == "ended")
        #expect(object["ended_on"] as? String == "2026-10-01")
        #expect(object["merchant_key"] as? String == "netflix")
        #expect(object["card_account_id"] as? String == CardSamples.c6.id.uuidString)
    }

    @Test func encodesNullEndedOnWhenConfirmed() throws {
        let recurrence = CardRecurrence(
            id: UUID(),
            cardAccountID: CardSamples.c6.id,
            merchantKey: "netflix",
            status: .confirmed,
            endedOn: nil
        )
        let data = try JSONEncoder().encode(recurrence)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["ended_on"] is NSNull)
    }
}
