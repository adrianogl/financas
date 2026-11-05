import Foundation

struct SpendingSuggestion: Identifiable, Hashable, Decodable, Sendable {
    let id: UUID
    var merchant: String
    var merchantKey: String
    var card: String
    var amount: Decimal
    var occurredAt: Date
    var reporterDevices: [UUID]
    var firstDeviceName: String
    var status: SpendingSuggestionStatus
    var expenseID: UUID?
    var entryID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case merchant
        case merchantKey = "merchant_key"
        case card
        case amount
        case occurredAt = "occurred_at"
        case reporterDevices = "reporter_devices"
        case firstDeviceName = "first_device_name"
        case status
        case expenseID = "expense_id"
        case entryID = "entry_id"
    }

    init(
        id: UUID,
        merchant: String,
        merchantKey: String,
        card: String,
        amount: Decimal,
        occurredAt: Date,
        reporterDevices: [UUID],
        firstDeviceName: String,
        status: SpendingSuggestionStatus,
        expenseID: UUID? = nil,
        entryID: UUID? = nil
    ) {
        self.id = id
        self.merchant = merchant
        self.merchantKey = merchantKey
        self.card = card
        self.amount = amount
        self.occurredAt = occurredAt
        self.reporterDevices = reporterDevices
        self.firstDeviceName = firstDeviceName
        self.status = status
        self.expenseID = expenseID
        self.entryID = entryID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        merchant = try container.decode(String.self, forKey: .merchant)
        merchantKey = try container.decode(String.self, forKey: .merchantKey)
        card = try container.decode(String.self, forKey: .card)
        amount = try container.decode(Decimal.self, forKey: .amount)
        let occurred = try container.decode(String.self, forKey: .occurredAt)
        guard let date = PostgresTimestamp.date(from: occurred) else {
            throw DecodingError.dataCorruptedError(forKey: .occurredAt, in: container, debugDescription: "Data inválida: \(occurred)")
        }
        occurredAt = date
        reporterDevices = try container.decode([UUID].self, forKey: .reporterDevices)
        firstDeviceName = try container.decode(String.self, forKey: .firstDeviceName)
        status = try container.decode(SpendingSuggestionStatus.self, forKey: .status)
        expenseID = try container.decodeIfPresent(UUID.self, forKey: .expenseID)
        entryID = try container.decodeIfPresent(UUID.self, forKey: .entryID)
    }

    var spentOn: CalendarDay {
        CalendarDay(date: occurredAt)
    }

    var entry: ExpenseEntry? {
        guard let entryID, let expenseID else { return nil }
        return ExpenseEntry(id: entryID, expenseID: expenseID, spentOn: spentOn, amount: amount)
    }
}
