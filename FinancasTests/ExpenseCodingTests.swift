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
        #expect(encoded["is_fixed"] as? Bool == false)
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

    @Test func decodesExpenseWithKind() throws {
        let json = #"""
        {"id":"\#(expenseID)","name":"Mercado","start_month":"2026-07-01","end_month":null,"is_fixed":false,"kind":"spending"}
        """#
        let expense = try SupabaseIncomeService.decoder.decode(Expense.self, from: Data(json.utf8))
        #expect(expense.kind == .spending)
    }

    @Test func encodesBillParts() throws {
        let partID = UUID()
        let bill = ExpenseBill(
            id: billID, expenseID: expenseID, month: YearMonth(year: 2026, month: 10),
            billAmount: 110, billDueDate: IncomeSamples.day(2026, 10, 10), paidOn: nil, paidAmount: nil,
            billParts: [partID: 110]
        )
        let encoded = try object(SupabaseIncomeService.encoder.encode(bill))
        let parts = try #require(encoded["bill_parts"] as? [String: Any])
        #expect(parts.count == 1)
        #expect((parts[partID.uuidString.lowercased()] as? NSNumber)?.decimalValue == 110)
        #expect(encoded["paid_parts"] is NSNull)
    }

    @Test func decodesBillParts() throws {
        let partID = UUID()
        let json = #"""
        {"id":"\#(billID)","expense_id":"\#(expenseID)","month":"2026-10-01","bill_amount":110.5,"bill_due_date":"2026-10-10","paid_on":null,"paid_amount":null,"bill_parts":{"\#(partID.uuidString.lowercased())":110.5},"paid_parts":null}
        """#
        let bill = try SupabaseIncomeService.decoder.decode(ExpenseBill.self, from: Data(json.utf8))
        #expect(bill.billParts == [partID: 110.5])
        #expect(bill.paidParts == nil)
    }

    @Test func decodesPartTermAndEntry() throws {
        let json = #"""
        {"id":"\#(billID)","part_id":"\#(expenseID)","valid_from":"2026-07-01","amount":300,"is_fixed":true,"average_from":"2026-08-01","is_active":false}
        """#
        let term = try SupabaseIncomeService.decoder.decode(ExpensePartTerm.self, from: Data(json.utf8))
        #expect(term.partID == expenseID)
        #expect(term.validFrom == YearMonth(year: 2026, month: 7))
        #expect(term.amount == 300)
        #expect(term.isFixed)
        #expect(term.averageFrom == YearMonth(year: 2026, month: 8))
        #expect(!term.isActive)

        let entryJSON = #"""
        {"id":"\#(billID)","expense_id":"\#(expenseID)","spent_on":"2026-10-17","amount":42.5}
        """#
        let entry = try SupabaseIncomeService.decoder.decode(ExpenseEntry.self, from: Data(entryJSON.utf8))
        #expect(entry.expenseID == expenseID)
        #expect(entry.spentOn == IncomeSamples.day(2026, 10, 17))
        #expect(entry.amount == 42.5)
    }
}
