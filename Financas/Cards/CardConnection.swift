import Foundation

struct CardConnection: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var itemID: String
    var status: CardConnectionStatus
    var lastSyncedAt: Date?
    var lastError: String?

    enum CodingKeys: String, CodingKey {
        case id
        case itemID = "item_id"
        case status
        case lastSyncedAt = "last_synced_at"
        case lastError = "last_error"
    }

    init(id: UUID, itemID: String, status: CardConnectionStatus, lastSyncedAt: Date?, lastError: String?) {
        self.id = id
        self.itemID = itemID
        self.status = status
        self.lastSyncedAt = lastSyncedAt
        self.lastError = lastError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        itemID = try container.decode(String.self, forKey: .itemID)
        status = try container.decode(CardConnectionStatus.self, forKey: .status)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        guard let text = try container.decodeIfPresent(String.self, forKey: .lastSyncedAt) else {
            lastSyncedAt = nil
            return
        }
        guard let date = PostgresTimestamp.date(from: text) else {
            throw DecodingError.dataCorruptedError(forKey: .lastSyncedAt, in: container, debugDescription: text)
        }
        lastSyncedAt = date
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(itemID, forKey: .itemID)
        try container.encode(status, forKey: .status)
        try container.encode(lastSyncedAt?.formatted(.iso8601), forKey: .lastSyncedAt)
        try container.encode(lastError, forKey: .lastError)
    }
}
