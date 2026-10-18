extension DetailRoute {
    init(_ occurrence: IncomeOccurrence) {
        self = .income(id: occurrence.id, month: occurrence.month)
    }
}
