import Foundation
import Testing
@testable import Financas

struct IncomeCodingTests {
    private let incomeID = "00000000-0000-0000-0000-000000000002"

    @Test func decodesAmountWithoutPrecisionLoss() throws {
        let json = #"{"id":"00000000-0000-0000-0000-0000000000aa","income_id":"\#(incomeID)","amount":13020.04,"valid_from":"2026-10-01"}"#
        let amount = try SupabaseIncomeService.decoder.decode(IncomeAmount.self, from: Data(json.utf8))
        #expect(amount.amount == IncomeSamples.money("13020.04"))
        #expect(amount.validFrom == YearMonth(year: 2026, month: 10))
    }

    @Test func encodesAmountAsExactNumber() throws {
        let data = try SupabaseIncomeService.encoder.encode(IncomeSamples.fixedAmount)
        #expect(String(decoding: data, as: UTF8.self).contains(#""amount":13020.04"#))
    }

    @Test func decodesIncomeFromRow() throws {
        let json = #"""
        {"id":"\#(incomeID)","user_id":"00000000-0000-0000-0000-0000000000ff","name":"Por hora","kind":"hourly",
         "day_of_month":15,"hours_per_day":8,"start_month":"2026-10-01","end_month":null,
         "one_off_date":null,"one_off_amount":null,"created_at":"2026-10-16T22:00:00+00:00"}
        """#
        let income = try SupabaseIncomeService.decoder.decode(Income.self, from: Data(json.utf8))
        #expect(income.kind == .hourly)
        #expect(income.hoursPerDay == 8)
        #expect(income.startMonth == YearMonth(year: 2026, month: 10))
        #expect(income.endMonth == nil)
    }

    @Test func encodesIncomeWithoutUserID() throws {
        let data = try SupabaseIncomeService.encoder.encode(IncomeSamples.hourly)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["user_id"] == nil)
        #expect(object["kind"] as? String == "hourly")
        #expect(object["start_month"] as? String == "2026-10-01")
    }

    @Test func encodesMissingOptionalsAsNull() throws {
        let data = try SupabaseIncomeService.encoder.encode(IncomeSamples.fixed)
        let object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["end_month"] is NSNull)
        #expect(object["hours_per_day"] is NSNull)

        let receipt = try SupabaseIncomeService.encoder.encode(IncomeSamples.receipt(IncomeSamples.fixed, YearMonth(year: 2026, month: 10), amount: 1))
        let receiptObject = try #require(try JSONSerialization.jsonObject(with: receipt) as? [String: Any])
        #expect(receiptObject["worked_days"] is NSNull)
    }

    @Test func networkErrorMapsToNetwork() {
        #expect(SupabaseIncomeService.incomeError(from: URLError(.notConnectedToInternet)) == .network)
        #expect(SupabaseIncomeService.incomeError(from: CocoaError(.fileNoSuchFile)) == .unknown)
    }
}
