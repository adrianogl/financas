import Foundation

struct ExpensePartDraft: Identifiable, Equatable {
    let id: UUID
    var name: String
    var isFixed: Bool
    var amount: Decimal?
}
