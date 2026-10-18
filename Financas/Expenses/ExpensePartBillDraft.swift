import Foundation

struct ExpensePartBillDraft: Equatable {
    var mode: ExpenseSheetMode
    var billAmount: Decimal
    var billDueDate: CalendarDay
    var paidAmount: Decimal
    var paidOn: CalendarDay
    private let base: ExpensePartBill

    init(value: ExpensePartValue, today: CalendarDay, mode: ExpenseSheetMode? = nil) {
        let bill = value.bill
        self.mode = mode ?? (value.isFixed || bill?.billAmount != nil || value.status == .paid ? .payment : .bill)
        billAmount = bill?.billAmount ?? value.amount
        billDueDate = value.dueDate
        paidAmount = bill?.paidAmount ?? bill?.billAmount ?? value.amount
        paidOn = bill?.paidOn ?? today
        base = bill ?? ExpensePartBill(id: UUID(), partID: value.part.id, month: value.month)
    }

    func billSaved() -> ExpensePartBill {
        var bill = base
        bill.billAmount = billAmount
        bill.billDueDate = billDueDate
        return bill
    }

    func paymentSaved() -> ExpensePartBill {
        var bill = base
        bill.paidAmount = paidAmount
        bill.paidOn = paidOn
        return bill
    }

    func billRemoved() -> ExpensePartBill? {
        var bill = base
        bill.billAmount = nil
        bill.billDueDate = nil
        return bill.isEmpty ? nil : bill
    }

    func paymentRemoved() -> ExpensePartBill? {
        var bill = base
        bill.paidAmount = nil
        bill.paidOn = nil
        return bill.isEmpty ? nil : bill
    }
}
