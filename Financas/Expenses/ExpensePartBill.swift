import Foundation

struct ExpensePartBill: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let partID: UUID
    let month: YearMonth
    var billAmount: Decimal?
    var billDueDate: CalendarDay?
    var paidOn: CalendarDay?
    var paidAmount: Decimal?

    var isEmpty: Bool {
        billAmount == nil && paidAmount == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case partID = "part_id"
        case month
        case billAmount = "bill_amount"
        case billDueDate = "bill_due_date"
        case paidOn = "paid_on"
        case paidAmount = "paid_amount"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(partID, forKey: .partID)
        try container.encode(month, forKey: .month)
        try container.encode(billAmount, forKey: .billAmount)
        try container.encode(billDueDate, forKey: .billDueDate)
        try container.encode(paidOn, forKey: .paidOn)
        try container.encode(paidAmount, forKey: .paidAmount)
    }
}
