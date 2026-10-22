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
}
