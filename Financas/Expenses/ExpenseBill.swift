import Foundation

struct ExpenseBill: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let expenseID: UUID
    let month: YearMonth
    var billAmount: Decimal?
    var billDueDate: CalendarDay?
    var paidOn: CalendarDay?
    var paidAmount: Decimal?
    var billParts: [UUID: Decimal]?
    var paidParts: [UUID: Decimal]?

    var isEmpty: Bool {
        billAmount == nil && paidAmount == nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case expenseID = "expense_id"
        case month
        case billAmount = "bill_amount"
        case billDueDate = "bill_due_date"
        case paidOn = "paid_on"
        case paidAmount = "paid_amount"
        case billParts = "bill_parts"
        case paidParts = "paid_parts"
    }

    init(
        id: UUID,
        expenseID: UUID,
        month: YearMonth,
        billAmount: Decimal? = nil,
        billDueDate: CalendarDay? = nil,
        paidOn: CalendarDay? = nil,
        paidAmount: Decimal? = nil,
        billParts: [UUID: Decimal]? = nil,
        paidParts: [UUID: Decimal]? = nil
    ) {
        self.id = id
        self.expenseID = expenseID
        self.month = month
        self.billAmount = billAmount
        self.billDueDate = billDueDate
        self.paidOn = paidOn
        self.paidAmount = paidAmount
        self.billParts = billParts
        self.paidParts = paidParts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        expenseID = try container.decode(UUID.self, forKey: .expenseID)
        month = try container.decode(YearMonth.self, forKey: .month)
        billAmount = try container.decodeIfPresent(Decimal.self, forKey: .billAmount)
        billDueDate = try container.decodeIfPresent(CalendarDay.self, forKey: .billDueDate)
        paidOn = try container.decodeIfPresent(CalendarDay.self, forKey: .paidOn)
        paidAmount = try container.decodeIfPresent(Decimal.self, forKey: .paidAmount)
        billParts = try Self.decodeParts(container, forKey: .billParts)
        paidParts = try Self.decodeParts(container, forKey: .paidParts)
    }

    private static func decodeParts(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> [UUID: Decimal]? {
        guard let raw = try container.decodeIfPresent([String: Decimal].self, forKey: key) else { return nil }
        var parts: [UUID: Decimal] = [:]
        for (rawID, amount) in raw {
            guard let partID = UUID(uuidString: rawID) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: container, debugDescription: "UUID inválido: \(rawID)")
            }
            parts[partID] = amount
        }
        return parts
    }

    private static func encodeParts(_ parts: [UUID: Decimal]?) -> [String: Decimal]? {
        parts.map { Dictionary(uniqueKeysWithValues: $0.map { ($0.key.uuidString.lowercased(), $0.value) }) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(expenseID, forKey: .expenseID)
        try container.encode(month, forKey: .month)
        try container.encode(billAmount, forKey: .billAmount)
        try container.encode(billDueDate, forKey: .billDueDate)
        try container.encode(paidOn, forKey: .paidOn)
        try container.encode(paidAmount, forKey: .paidAmount)
        try container.encode(Self.encodeParts(billParts), forKey: .billParts)
        try container.encode(Self.encodeParts(paidParts), forKey: .paidParts)
    }
}
