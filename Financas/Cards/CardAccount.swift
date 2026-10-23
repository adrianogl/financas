import Foundation

struct CardAccount: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var connectionID: UUID
    var name: String
    var lastDigits: String
    var nickname: String
    var brandLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case connectionID = "connection_id"
        case name
        case lastDigits = "last_digits"
        case nickname
        case brandLabel = "brand_label"
    }
}
