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
        let openParts = occurrence.parts.filter { $0.status != .paid }
        let shownParts = openParts.isEmpty ? occurrence.parts : openParts
        billPartValues = shownParts.map { value in
            ExpenseBillPartDraft(
                id: value.part.id,
                name: value.part.name,
                amount: value.bill?.billAmount ?? value.amount
            )
        }
        paymentPartValues = shownParts.map { value in
            ExpenseBillPartDraft(
                id: value.part.id,
                name: value.part.name,
                amount: value.bill?.paidAmount ?? value.bill?.billAmount ?? value.amount
            )
        }
        billAmount = bill?.billAmount ?? occurrence.amount
        billDueDate = occurrence.dueDate
        paidAmount = bill?.paidAmount ?? bill?.billAmount ?? occurrence.estimate.amount
        paidOn = (hasParts ? occurrence.paidOn : bill?.paidOn) ?? today
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

    private func total(of values: [ExpenseBillPartDraft]) -> Decimal {
        values.map(\.amount).reduce(0, +)
    }

    func partBillsSaved(for occurrence: ExpenseOccurrence) -> [ExpensePartBill] {
        billPartValues.compactMap { value in
            partBill(of: value.id, in: occurrence).map { bill in
                var bill = bill
                bill.billAmount = value.amount
                bill.billDueDate = billDueDate
                return bill
            }
        }
    }

    func partPaymentsSaved(for occurrence: ExpenseOccurrence) -> [ExpensePartBill] {
        paymentPartValues.compactMap { value in
            partBill(of: value.id, in: occurrence).map { bill in
                var bill = bill
                bill.paidAmount = value.amount
                bill.paidOn = paidOn
                return bill
            }
        }
    }

    func partBillsRemoved(for occurrence: ExpenseOccurrence) -> [ExpensePartBill] {
        occurrence.parts.compactMap(\.bill).map { bill in
            var bill = bill
            bill.billAmount = nil
            bill.billDueDate = nil
            return bill
        }
    }

    func partPaymentsRemoved(for occurrence: ExpenseOccurrence) -> [ExpensePartBill] {
        occurrence.parts.compactMap(\.bill).map { bill in
            var bill = bill
            bill.paidAmount = nil
            bill.paidOn = nil
            return bill
        }
    }

    private func partBill(of partID: UUID, in occurrence: ExpenseOccurrence) -> ExpensePartBill? {
        guard let value = occurrence.parts.first(where: { $0.part.id == partID }) else { return nil }
        return value.bill ?? ExpensePartBill(id: UUID(), partID: partID, month: occurrence.month)
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
