extension DetailRoute {
    init(_ occurrence: ExpenseOccurrence) {
        self = .expense(id: occurrence.id, month: occurrence.month)
    }
}
