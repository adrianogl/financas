import Foundation

enum SuggestionReviewTab: Hashable {
    case pending
    case dismissed
}

struct SuggestionConflict: Identifiable, Equatable {
    let launchedName: String
    let chosen: Expense

    var id: UUID { chosen.id }
}
