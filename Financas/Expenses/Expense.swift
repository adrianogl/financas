import Foundation

struct Expense: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var name: String
    var startMonth: YearMonth
    var endMonth: YearMonth?
    var isFixed = false
    var kind: ExpenseKind = .bill

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startMonth = "start_month"
        case endMonth = "end_month"
        case isFixed = "is_fixed"
        case kind
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startMonth, forKey: .startMonth)
        try container.encode(endMonth, forKey: .endMonth)
        try container.encode(isFixed, forKey: .isFixed)
        try container.encode(kind, forKey: .kind)
    }
}
