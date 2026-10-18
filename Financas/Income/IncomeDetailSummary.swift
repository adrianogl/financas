struct IncomeDetailSummary: Equatable {
    let rule: String
    let current: IncomeAmount?
    let history: [DetailHistoryEntry]

    static func make(occurrence: IncomeOccurrence, snapshot: IncomeSnapshot, today: CalendarDay) -> IncomeDetailSummary {
        let income = occurrence.income
        guard income.kind != .oneOff else {
            let date = income.oneOffDate.map { IncomeFormat.shortDate($0) } ?? ""
            return IncomeDetailSummary(rule: "Receita avulsa · \(date)", current: nil, history: [])
        }
        let current = snapshot.amounts
            .filter { $0.incomeID == income.id && $0.validFrom <= today.yearMonth }
            .max { $0.validFrom < $1.validFrom }
        return IncomeDetailSummary(
            rule: "Receita \(income.kind.title.lowercased()) · todo dia \(income.dayOfMonth ?? 1)",
            current: current,
            history: history(of: income, before: occurrence.month, snapshot: snapshot)
        )
    }

    private static func history(of income: Income, before month: YearMonth, snapshot: IncomeSnapshot) -> [DetailHistoryEntry] {
        guard let start = income.startMonth else { return [] }
        var entries: [DetailHistoryEntry] = []
        var cursor = month.previous
        while entries.count < DetailConstants.historyMonths, cursor >= start {
            let received = snapshot.receipts.first { $0.incomeID == income.id && $0.month == cursor }
            entries.append(DetailHistoryEntry(month: cursor, amount: received?.amount))
            cursor = cursor.previous
        }
        return entries
    }
}
