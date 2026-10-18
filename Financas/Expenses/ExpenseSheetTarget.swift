import Foundation

struct ExpenseSheetTarget: Identifiable {
    let occurrence: ExpenseOccurrence
    let mode: ExpenseSheetMode?
    var partID: UUID? = nil

    var id: String {
        partID.map { "\(occurrence.id)-\($0)" } ?? occurrence.id
    }
}
