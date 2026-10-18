import Foundation

struct ExpenseBillPartDraft: Identifiable, Equatable {
    let id: UUID
    let name: String
    var amount: Decimal
}
