import Foundation

struct IncomeDraft: Equatable {
    var kind: IncomeKind
    var name: String
    var amount: Decimal?
    var amountValidFrom: YearMonth
    var dayOfMonth: Int
    var hoursPerDay: Decimal
    var startMonth: YearMonth
    var endMonth: YearMonth?
    var oneOffDate: CalendarDay
    let incomeID: UUID
    let isNew: Bool
    private let amountID: UUID
    private let originalAmount: Decimal?

    init(today: CalendarDay, kind: IncomeKind = .fixed) {
        self.kind = kind
        name = ""
        amount = nil
        amountValidFrom = today.yearMonth
        dayOfMonth = 1
        hoursPerDay = IncomeConstants.defaultHoursPerDay
        startMonth = today.yearMonth
        endMonth = nil
        oneOffDate = today
        incomeID = UUID()
        isNew = true
        amountID = UUID()
        originalAmount = nil
    }

    init(income: Income, snapshot: IncomeSnapshot, today: CalendarDay) {
        let current = snapshot.amounts
            .filter { $0.incomeID == income.id && $0.validFrom <= today.yearMonth }
            .max { $0.validFrom < $1.validFrom }?
            .amount
        kind = income.kind
        name = income.name
        amount = income.kind == .oneOff ? income.oneOffAmount : current
        amountValidFrom = today.yearMonth
        dayOfMonth = income.dayOfMonth ?? 1
        hoursPerDay = income.hoursPerDay ?? IncomeConstants.defaultHoursPerDay
        startMonth = income.startMonth ?? today.yearMonth
        endMonth = income.endMonth
        oneOffDate = income.oneOffDate ?? today
        incomeID = income.id
        isNew = false
        amountID = UUID()
        originalAmount = amount
    }

    var amountChanged: Bool {
        !isNew && amount != originalAmount
    }

    var validationMessage: String? {
        if trimmedName.isEmpty {
            return "Dê um nome para a receita."
        }
        guard let amount, amount > 0 else {
            return "Informe um valor maior que zero."
        }
        if kind != .oneOff, let endMonth, endMonth < startMonth {
            return "O mês de fim precisa ser depois do início."
        }
        if kind == .hourly, hoursPerDay <= 0 {
            return "Informe as horas por dia."
        }
        return nil
    }

    func build() -> (Income, IncomeAmount?) {
        let id = incomeID
        let value = amount ?? 0

        guard kind != .oneOff else {
            let income = Income(id: id, name: trimmedName, kind: kind, oneOffDate: oneOffDate, oneOffAmount: value)
            return (income, nil)
        }

        let income = Income(
            id: id,
            name: trimmedName,
            kind: kind,
            dayOfMonth: dayOfMonth,
            hoursPerDay: kind == .hourly ? hoursPerDay : nil,
            startMonth: startMonth,
            endMonth: endMonth
        )

        let validFrom: YearMonth
        if isNew {
            validFrom = kind == .hourly ? startMonth.previous : startMonth
        } else if amountChanged {
            validFrom = amountValidFrom
        } else {
            return (income, nil)
        }
        return (income, IncomeAmount(id: amountID, incomeID: id, amount: value, validFrom: validFrom))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
