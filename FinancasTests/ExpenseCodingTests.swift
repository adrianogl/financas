import Foundation
import Testing
@testable import Financas

struct ExpenseCodingTests {
    private let expenseID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private let billID = UUID(uuidString: "00000000-0000-0000-0000-0000000000bb")!

    private func object(_ data: Data) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func decodesBillWithOnlyPayment() throws {
        let json = #"""
        {"id":"\#(billID)","expense_id":"\#(expenseID)","month":"2026-10-01","bill_amount":null,"bill_due_date":null,"paid_on":"2026-10-09","paid_amount":1150}
        """#
        let bill = try SupabaseIncomeService.decoder.decode(ExpenseBill.self, from: Data(json.utf8))
        #expect(bill.billAmount == nil)
        #expect(bill.billDueDate == nil)
        #expect(bill.paidOn == IncomeSamples.day(2026, 10, 9))
        #expect(bill.paidAmount == 1150)
        #expect(!bill.isEmpty)
    }

    @Test func encodesNullBillColumns() throws {
        let bill = ExpenseBill(
            id: billID, expenseID: expenseID, month: YearMonth(year: 2026, month: 10),
            billAmount: nil, billDueDate: nil, paidOn: IncomeSamples.day(2026, 10, 9), paidAmount: 1150
        )
        let encoded = try object(SupabaseIncomeService.encoder.encode(bill))
        #expect(encoded["bill_amount"] is NSNull)
        #expect(encoded["bill_due_date"] is NSNull)
        #expect(encoded["isEmpty"] == nil)
        #expect(encoded["is_empty"] == nil)
    }

    @Test func encodesNullEndMonth() throws {
        let expense = Expense(id: expenseID, name: "Internet", startMonth: YearMonth(year: 2026, month: 7), endMonth: nil)
        let encoded = try object(SupabaseIncomeService.encoder.encode(expense))
        #expect(encoded["end_month"] is NSNull)
        #expect(encoded["start_month"] as? String == "2026-07-01")
    }

    @Test func decodesTerm() throws {
        let json = #"""
        {"id":"\#(billID)","expense_id":"\#(expenseID)","valid_from":"2026-07-01","average_from":"2026-07-01","day_of_month":13,"estimated_amount":180}
        """#
        let term = try SupabaseIncomeService.decoder.decode(ExpenseTerm.self, from: Data(json.utf8))
        #expect(term.validFrom == YearMonth(year: 2026, month: 7))
        #expect(term.averageFrom == YearMonth(year: 2026, month: 7))
        #expect(term.dayOfMonth == 13)
        #expect(term.estimatedAmount == 180)
    }
}
