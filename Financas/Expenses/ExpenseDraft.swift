import Foundation

struct ExpenseDraft: Equatable {
    var name: String
    var kind: ExpenseKind
    var isFixed: Bool
    var estimatedAmount: Decimal?
    var dayOfMonth: Int
    var startMonth: YearMonth
    var endMonth: YearMonth?
    var parts: [ExpensePartDraft]
    let expenseID: UUID
    let isNew: Bool
    private let newTermID: UUID
    private let currentTerm: ExpenseTerm?
    private let knownTerms: [ExpenseTerm]
    private let openedMonth: YearMonth
    private let isOpenedMonthRegistered: Bool
    private let openedParts: [ExpensePartDraft]
    private let knownParts: [ExpensePart]
    private let knownPartTerms: [ExpensePartTerm]

    init(today: CalendarDay) {
        name = ""
        kind = .bill
        isFixed = true
        estimatedAmount = nil
        dayOfMonth = 1
        startMonth = today.yearMonth
        endMonth = nil
        parts = []
        expenseID = UUID()
        isNew = true
        newTermID = UUID()
        currentTerm = nil
        knownTerms = []
        openedMonth = today.yearMonth
        isOpenedMonthRegistered = false
        openedParts = []
        knownParts = []
        knownPartTerms = []
    }

    init(expense: Expense, snapshot: ExpenseSnapshot, today: CalendarDay) {
        let term = ExpenseSchedule.term(for: expense, in: today.yearMonth, snapshot: snapshot)
        let expenseParts = snapshot.parts.filter { $0.expenseID == expense.id }
        let partIDs = Set(expenseParts.map(\.id))
        let billRegistered = snapshot.bills.contains { $0.expenseID == expense.id && $0.month == today.yearMonth && !$0.isEmpty }
        let partRegistered = snapshot.partBills.contains { partIDs.contains($0.partID) && $0.month == today.yearMonth && !$0.isEmpty }
        let registered = billRegistered || partRegistered
        let effective = Self.effectiveMonth(opened: today.yearMonth, start: expense.startMonth, registered: registered)
        let loadedParts = ExpensePartSchedule.activeParts(of: expense, in: effective, snapshot: snapshot).compactMap { part in
            ExpensePartSchedule.term(for: part, in: effective, snapshot: snapshot).map {
                ExpensePartDraft(id: part.id, name: part.name, isFixed: $0.isFixed, amount: $0.amount, dayOfMonth: $0.dayOfMonth)
            }
        }

        name = expense.name
        kind = expense.kind
        isFixed = expense.isFixed
        estimatedAmount = term?.estimatedAmount
        dayOfMonth = term?.dayOfMonth ?? 1
        startMonth = expense.startMonth
        endMonth = expense.endMonth
        parts = loadedParts
        expenseID = expense.id
        isNew = false
        newTermID = UUID()
        currentTerm = term
        knownTerms = snapshot.terms.filter { $0.expenseID == expense.id }
        openedMonth = today.yearMonth
        isOpenedMonthRegistered = registered
        openedParts = loadedParts
        knownParts = expenseParts
        knownPartTerms = snapshot.partTerms.filter { partIDs.contains($0.partID) }
    }

    var effectiveMonth: YearMonth {
        Self.effectiveMonth(opened: openedMonth, start: startMonth, registered: isOpenedMonthRegistered)
    }

    var validationMessage: String? {
        if trimmedName.isEmpty {
            return "Dê um nome para a despesa."
        }
        if hasParts {
            if let partsMessage {
                return partsMessage
            }
        } else {
            guard let estimatedAmount, estimatedAmount > 0 else {
                return "Informe um valor maior que zero."
            }
        }
        if let endMonth, endMonth < startMonth {
            return "O mês de fim precisa ser depois do início."
        }
        return nil
    }

    mutating func addPart() {
        parts.append(ExpensePartDraft(id: UUID(), name: "", isFixed: false, amount: nil))
    }

    mutating func removePart(id: UUID) {
        parts.removeAll { $0.id == id }
        guard parts.isEmpty, !openedParts.isEmpty else { return }
        estimatedAmount = openedParts.compactMap(\.amount).reduce(0, +)
        isFixed = false
    }

    func build(today: CalendarDay) -> (Expense, ExpenseTerm?) {
        let expense = Expense(
            id: expenseID,
            name: trimmedName,
            startMonth: startMonth,
            endMonth: endMonth,
            isFixed: isFixed,
            kind: kind
        )
        let day = kind == .spending ? 1 : dayOfMonth

        guard !isNew, let currentTerm else {
            let value = hasParts ? partsTotal : estimatedAmount ?? 0
            let term = ExpenseTerm(
                id: newTermID,
                expenseID: expenseID,
                validFrom: startMonth,
                estimatedAmount: value,
                dayOfMonth: day,
                averageFrom: startMonth
            )
            return (expense, term)
        }

        let value = hasParts ? currentTerm.estimatedAmount : estimatedAmount ?? 0
        let estimateChanged = !hasParts && (value != currentTerm.estimatedAmount || isLeavingParts)
        let dayChanged = day != currentTerm.dayOfMonth
        guard estimateChanged || dayChanged else { return (expense, nil) }

        let validFrom = hasParts || isLeavingParts ? effectiveMonth : max(today.yearMonth, startMonth)
        let averageFrom = estimateChanged ? restartedAverage(from: validFrom, today: today) : currentTerm.averageFrom
        let reusedID = knownTerms.first { $0.validFrom == validFrom }?.id ?? newTermID
        let term = ExpenseTerm(
            id: reusedID,
            expenseID: expenseID,
            validFrom: validFrom,
            estimatedAmount: value,
            dayOfMonth: day,
            averageFrom: averageFrom
        )
        return (expense, term)
    }

    func buildParts(today: CalendarDay) -> ExpensePartChanges {
        guard kind == .bill else { return ExpensePartChanges(parts: [], terms: []) }
        let month = isNew ? startMonth : effectiveMonth
        let restarted = isNew ? startMonth : restartedAverage(from: month, today: today)
        let draftIDs = Set(parts.map(\.id))
        var matchedIDs = Set<UUID>()
        var changes = ExpensePartChanges(parts: [], terms: [])

        for (position, draft) in parts.enumerated() {
            let known = knownParts.first { $0.id == draft.id } ?? knownParts.first { part in
                !draftIDs.contains(part.id) && !matchedIDs.contains(part.id) && Self.key(part.name) == Self.key(draft.name)
            }
            let partID = known?.id ?? draft.id
            matchedIDs.insert(partID)
            let part = ExpensePart(id: partID, expenseID: expenseID, name: Self.trimmed(draft.name), position: position)
            let current = partTerm(of: partID, in: month)
            let isActive = current?.isActive == true
            if part != known || !isActive {
                changes.parts.append(part)
            }
            if let term = changedTerm(for: draft, partID: partID, current: current, month: month, restarted: restarted) {
                changes.terms += superseding(term)
            }
        }

        for removed in openedParts where !matchedIDs.contains(removed.id) {
            guard let current = partTerm(of: removed.id, in: month), current.isActive else { continue }
            changes.terms += superseding(ExpensePartTerm(
                id: partTermID(of: removed.id, in: month),
                partID: removed.id,
                validFrom: month,
                amount: current.amount,
                isFixed: current.isFixed,
                averageFrom: current.averageFrom,
                isActive: false,
                dayOfMonth: current.dayOfMonth
            ))
        }
        return changes
    }

    private func changedTerm(
        for draft: ExpensePartDraft,
        partID: UUID,
        current: ExpensePartTerm?,
        month: YearMonth,
        restarted: YearMonth
    ) -> ExpensePartTerm? {
        let amount = draft.amount ?? 0
        let averageFrom: YearMonth
        if let current, current.isActive {
            let amountChanged = amount != current.amount
            guard amountChanged || draft.isFixed != current.isFixed || draft.dayOfMonth != current.dayOfMonth else { return nil }
            averageFrom = amountChanged ? restarted : current.averageFrom
        } else if let last = lastActiveTerm(of: partID, through: month), last.amount == amount {
            averageFrom = last.averageFrom
        } else {
            averageFrom = restarted
        }
        return ExpensePartTerm(
            id: partTermID(of: partID, in: month),
            partID: partID,
            validFrom: month,
            amount: amount,
            isFixed: draft.isFixed,
            averageFrom: averageFrom,
            isActive: true,
            dayOfMonth: draft.dayOfMonth
        )
    }

    private func superseding(_ term: ExpensePartTerm) -> [ExpensePartTerm] {
        let later = knownPartTerms
            .filter { $0.partID == term.partID && $0.validFrom > term.validFrom }
            .sorted { $0.validFrom < $1.validFrom }
            .map {
                ExpensePartTerm(
                    id: $0.id,
                    partID: term.partID,
                    validFrom: $0.validFrom,
                    amount: term.amount,
                    isFixed: term.isFixed,
                    averageFrom: term.averageFrom,
                    isActive: term.isActive,
                    dayOfMonth: term.dayOfMonth
                )
            }
        return [term] + later
    }

    private func partTerm(of partID: UUID, in month: YearMonth) -> ExpensePartTerm? {
        knownPartTerms
            .filter { $0.partID == partID && $0.validFrom <= month }
            .max { $0.validFrom < $1.validFrom }
    }

    private func lastActiveTerm(of partID: UUID, through month: YearMonth) -> ExpensePartTerm? {
        knownPartTerms
            .filter { $0.partID == partID && $0.validFrom <= month && $0.isActive }
            .max { $0.validFrom < $1.validFrom }
    }

    private func partTermID(of partID: UUID, in month: YearMonth) -> UUID {
        knownPartTerms.first { $0.partID == partID && $0.validFrom == month }?.id ?? UUID()
    }

    private func restartedAverage(from month: YearMonth, today: CalendarDay) -> YearMonth {
        month > today.yearMonth ? month : month.next
    }

    private var hasParts: Bool {
        kind == .bill && !parts.isEmpty
    }

    private var isLeavingParts: Bool {
        kind == .bill && parts.isEmpty && !openedParts.isEmpty
    }

    private var partsTotal: Decimal {
        parts.compactMap(\.amount).reduce(0, +)
    }

    private var partsMessage: String? {
        let keys = parts.map { Self.key($0.name) }
        if keys.contains(where: \.isEmpty) {
            return "Dê um nome para cada parte."
        }
        if Set(keys).count != keys.count {
            return ExpenseConstants.duplicatePartNameMessage
        }
        if let knownNameMessage {
            return knownNameMessage
        }
        if parts.contains(where: { ($0.amount ?? 0) <= 0 }) {
            return "Informe o valor de cada parte."
        }
        return nil
    }

    private var knownNameMessage: String? {
        let draftIDs = Set(parts.map(\.id))
        let knownIDs = Set(knownParts.map(\.id))
        for draft in parts {
            let key = Self.key(draft.name)
            guard let owner = knownParts.first(where: { $0.id != draft.id && Self.key($0.name) == key }) else { continue }
            if draftIDs.contains(owner.id) {
                return ExpenseConstants.duplicatePartNameMessage
            }
            if knownIDs.contains(draft.id) {
                return ExpenseConstants.endedPartNameMessage
            }
        }
        return nil
    }

    private var trimmedName: String {
        Self.trimmed(name)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func key(_ text: String) -> String {
        trimmed(text).lowercased()
    }

    private static func effectiveMonth(opened: YearMonth, start: YearMonth, registered: Bool) -> YearMonth {
        let base = max(opened, start)
        return registered && base == opened ? base.next : base
    }
}
