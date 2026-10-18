import Foundation

struct SpendingEntryTarget: Identifiable {
    let draft: ExpenseEntryDraft
    let entry: ExpenseEntry?

    var id: UUID { draft.entryID }
}
