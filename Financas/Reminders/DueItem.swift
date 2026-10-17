import Foundation

struct DueItem: Hashable, Sendable {
    let id: String
    let kind: DueItemKind
    let title: String
    let amount: Decimal
    let dueDate: CalendarDay
}
