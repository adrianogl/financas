struct IncomeMonthList {
    let open: [IncomeOccurrence]
    let received: [IncomeOccurrence]

    init(occurrences: [IncomeOccurrence]) {
        open = occurrences
            .filter { $0.status != .received }
            .sorted { ($0.status == .overdue ? 0 : 1, $0.dueDate) < ($1.status == .overdue ? 0 : 1, $1.dueDate) }
        received = occurrences.filter { $0.status == .received }
    }

    var all: [IncomeOccurrence] {
        open + received
    }
}
