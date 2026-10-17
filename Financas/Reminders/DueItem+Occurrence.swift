extension DueItem {
    init(occurrence: IncomeOccurrence) {
        self.init(
            id: occurrence.id,
            kind: .income,
            title: IncomeFormat.occurrenceTitle(occurrence),
            amount: occurrence.expectedAmount,
            dueDate: occurrence.dueDate
        )
    }
}
