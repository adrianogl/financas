import Foundation

struct ExpensePartValue: Hashable, Identifiable {
    let part: ExpensePart
    let amount: Decimal
    let origin: ExpensePartOrigin
    let isFixed: Bool

    var id: UUID { part.id }
}
