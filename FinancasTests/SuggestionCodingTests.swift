import Foundation
import Testing
@testable import Financas

struct SuggestionCodingTests {
    @Test func decodesTheReportReturnedByTheDatabase() throws {
        let json = """
        {"created": false, "suggestion": {
          "id": "6F1E2B3C-0000-4000-8000-000000000001", "user_id": "6F1E2B3C-0000-4000-8000-0000000000AA",
          "merchant": "PADARIA PAO QUENTE", "merchant_key": "PADARIA PAO QUENTE", "card": "Nubank",
          "amount": 18.90, "occurred_at": "2026-11-05T11:42:07.123+00:00",
          "reporter_devices": ["6F1E2B3C-0000-4000-8000-0000000000D1", "6F1E2B3C-0000-4000-8000-0000000000D2"],
          "first_device_name": "iPhone", "status": "confirmed",
          "expense_id": "6F1E2B3C-0000-4000-8000-0000000000E1", "entry_id": "6F1E2B3C-0000-4000-8000-0000000000F1",
          "resolved_at": "2026-11-05T11:43:00+00:00", "created_at": "2026-11-05T11:42:08+00:00"
        }}
        """

        let report = try JSONDecoder().decode(SuggestionReport.self, from: Data(json.utf8))

        #expect(report.created == false)
        #expect(report.suggestion.amount == ExpenseSamples.money("18.90"))
        #expect(report.suggestion.status == .confirmed)
        #expect(report.suggestion.reporterDevices.count == 2)
        #expect(report.suggestion.entry?.expenseID == UUID(uuidString: "6F1E2B3C-0000-4000-8000-0000000000E1"))
        #expect(report.suggestion.occurredAt == PostgresTimestamp.date(from: "2026-11-05T11:42:07.123Z"))
    }

    @Test func decodesAPendingSuggestionWithoutEntry() throws {
        let json = """
        {"id": "6F1E2B3C-0000-4000-8000-000000000002", "merchant": "DROGARIA", "merchant_key": "DROGARIA", "card": "",
         "amount": 42.5, "occurred_at": "2026-11-04T22:10:00+00:00", "reporter_devices": ["6F1E2B3C-0000-4000-8000-0000000000D1"],
         "first_device_name": "iPhone", "status": "pending", "expense_id": null, "entry_id": null}
        """

        let suggestion = try JSONDecoder().decode(SpendingSuggestion.self, from: Data(json.utf8))

        #expect(suggestion.status == .pending)
        #expect(suggestion.entry == nil)
    }
}
