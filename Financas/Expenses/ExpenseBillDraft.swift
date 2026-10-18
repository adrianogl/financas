import Foundation

struct ExpenseBillDraft: Equatable {
    var mode: ExpenseSheetMode
    var billAmount: Decimal
    var billDueDate: CalendarDay
    var paidAmount: Decimal
    var paidOn: CalendarDay
    var billPartValues: [ExpenseBillPartDraft]
    var paymentPartValues: [ExpenseBillPartDraft]

    var parts: [ExpenseBillPartDraft] {
        get { mode == .bill ? billPartValues : paymentPartValues }
        set {
            switch mode {
            case .bill: billPartValues = newValue
            case .payment: paymentPartValues = newValue
            }
        }
    }

    var partsTotal: Decimal {
        total(of: parts)
    }

    init(occurrence: ExpenseOccurrence, today: CalendarDay, mode: ExpenseSheetMode? = nil) {
        let bill = occurrence.bill
        let hasParts = !occurrence.parts.isEmpty
        let allFixed = hasParts && occurrence.parts.allSatisfy(\.isFixed)
        let isFixedExpense = hasParts ? allFixed : occurrence.expense.isFixed
        self.mode = mode ?? (occurrence.hasBill || occurrence.status == .paid || isFixedExpense ? .payment : .bill)
        billPartValues = occurrence.parts.map { value in
            ExpenseBillPartDraft(
                id: value.part.id,
                name: value.part.name,
                amount: bill?.billParts?[value.part.id] ?? value.amount
            )
        }
        paymentPartValues = occurrence.parts.map { value in
            ExpenseBillPartDraft(
                id: value.part.id,
                name: value.part.name,
                amount: bill?.paidParts?[value.part.id] ?? bill?.billParts?[value.part.id] ?? value.amount
            )
        }
        billAmount = bill?.billAmount ?? occurrence.amount
        billDueDate = occurrence.dueDate
        paidAmount = bill?.paidAmount ?? bill?.billAmount ?? occurrence.estimate.amount
        paidOn = bill?.paidOn ?? today
    }

    func billSaved(for occurrence: ExpenseOccurrence) -> ExpenseBill {
        var bill = base(for: occurrence)
        bill.billAmount = billPartValues.isEmpty ? billAmount : total(of: billPartValues)
        bill.billDueDate = billDueDate
        if !billPartValues.isEmpty { bill.billParts = amountsByPart(billPartValues) }
        return bill
    }

    func paymentSaved(for occurrence: ExpenseOccurrence) -> ExpenseBill {
        var bill = base(for: occurrence)
        bill.paidAmount = paymentPartValues.isEmpty ? paidAmount : total(of: paymentPartValues)
        bill.paidOn = paidOn
        if !paymentPartValues.isEmpty { bill.paidParts = amountsByPart(paymentPartValues) }
        return bill
    }

    func billRemoved(for occurrence: ExpenseOccurrence) -> ExpenseBill? {
        var bill = base(for: occurrence)
        bill.billAmount = nil
        bill.billDueDate = nil
        bill.billParts = nil
        return bill.isEmpty ? nil : bill
    }

    func paymentRemoved(for occurrence: ExpenseOccurrence) -> ExpenseBill? {
        var bill = base(for: occurrence)
        bill.paidAmount = nil
        bill.paidOn = nil
        bill.paidParts = nil
        return bill.isEmpty ? nil : bill
    }

    private func total(of values: [ExpenseBillPartDraft]) -> Decimal {
        values.map(\.amount).reduce(0, +)
    }

    private func amountsByPart(_ values: [ExpenseBillPartDraft]) -> [UUID: Decimal] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0.amount) })
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
