import Foundation

struct SuggestionChoice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let hint: String?
}

struct SuggestionSnippetContent: Equatable {
    let suggestionID: UUID
    let amount: String
    let merchant: String
    let detail: String
    let suggested: SuggestionChoice?
    let alternatives: [SuggestionChoice]
}

enum SuggestionResultAction: Equatable {
    case undo(suggestionID: UUID)
    case move(suggestionID: UUID, expenseID: UUID, expenseName: String)
}

enum SuggestionResultTone: Equatable {
    case done
    case info
    case attention
}
