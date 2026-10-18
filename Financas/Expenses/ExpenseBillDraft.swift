import Foundation

struct ExpenseBillDraft: Equatable {
    var mode: ExpenseSheetMode
    var billAmount: Decimal
    var billDueDate: CalendarDay
    var paidAmount: Decimal
    var paidOn: CalendarDay

    init(occurrence: ExpenseOccurrence, today: CalendarDay, mode: ExpenseSheetMode? = nil) {
        let bill = occurrence.bill
        self.mode = mode ?? (occurrence.hasBill || occurrence.status == .paid ? .payment : .bill)
        billAmount = bill?.billAmount ?? occurrence.amount
        billDueDate = occurrence.dueDate
        paidAmount = bill?.paidAmount ?? bill?.billAmount ?? occurrence.estimate.amount
        paidOn = bill?.paidOn ?? today
    }

    func billSaved(for occurrence: ExpenseOccurrence) -> ExpenseBill {
        var bill = base(for: occurrence)
        bill.billAmount = billAmount
        bill.billDueDate = billDueDate
        return bill
    }

    func paymentSaved(for occurrence: ExpenseOccurrence) -> ExpenseBill {
        var bill = base(for: occurrence)
        bill.paidAmount = paidAmount
        bill.paidOn = paidOn
        return bill
    }

    func billRemoved(for occurrence: ExpenseOccurrence) -> ExpenseBill? {
        var bill = base(for: occurrence)
        bill.billAmount = nil
        bill.billDueDate = nil
        return bill.isEmpty ? nil : bill
    }

    func paymentRemoved(for occurrence: ExpenseOccurrence) -> ExpenseBill? {
        var bill = base(for: occurrence)
        bill.paidAmount = nil
        bill.paidOn = nil
        return bill.isEmpty ? nil : bill
    }

    private func base(for occurrence: ExpenseOccurrence) -> ExpenseBill {
        occurrence.bill ?? ExpenseBill(
            id: UUID(),
            expenseID: occurrence.expense.id,
            month: occurrence.month,
            billAmount: nil,
            billDueDate: nil,
            paidOn: nil,
            paidAmount: nil
        )
    }
}
