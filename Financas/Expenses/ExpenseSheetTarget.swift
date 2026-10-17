struct ExpenseSheetTarget: Identifiable {
    let occurrence: ExpenseOccurrence
    let mode: ExpenseSheetMode?

    var id: String {
        occurrence.id
    }
}
