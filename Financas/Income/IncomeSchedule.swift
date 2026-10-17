import Foundation

enum IncomeSchedule {
    static func occurrence(of income: Income, in month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> IncomeOccurrence? {
        let receipt = snapshot.receipts.first { $0.incomeID == income.id && $0.month == month }

        switch income.kind {
        case .oneOff:
            guard let date = income.oneOffDate, let amount = income.oneOffAmount, date.yearMonth == month else { return nil }
            return makeOccurrence(income, month, dueDate: date, expected: amount, receipt: receipt, today: today)

        case .fixed:
            guard isActive(income, in: month), let day = income.dayOfMonth,
                  let amount = amount(for: income, in: month, snapshot: snapshot) else { return nil }
            let dueDate = BusinessCalendar.dueDate(for: month.day(day), rule: snapshot.settings.nonBusinessDay)
            return makeOccurrence(income, month, dueDate: dueDate, expected: amount, receipt: receipt, today: today)

        case .hourly:
            let reference = month.previous
            guard isActive(income, in: month), let day = income.dayOfMonth, let hours = income.hoursPerDay,
                  let rate = amount(for: income, in: reference, snapshot: snapshot) else { return nil }
            let businessDays = BusinessCalendar.businessDays(in: reference)
            let dueDate = BusinessCalendar.dueDate(for: month.day(day), rule: snapshot.settings.nonBusinessDay)
            return makeOccurrence(
                income, month, dueDate: dueDate, expected: Decimal(businessDays) * hours * rate, receipt: receipt, today: today,
                reference: reference, businessDays: businessDays, rate: rate
            )
        }
    }

    static func occurrences(in month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> [IncomeOccurrence] {
        snapshot.incomes
            .compactMap { occurrence(of: $0, in: month, snapshot: snapshot, today: today) }
            .sorted(by: ordered)
    }

    static func overdue(before month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> [IncomeOccurrence] {
        let earlier = snapshot.incomes.flatMap { income in
            months(of: income, before: month).compactMap { occurrence(of: income, in: $0, snapshot: snapshot, today: today) }
        }
        return (earlier + early(in: month, snapshot: snapshot, today: today))
            .filter { $0.status == .overdue }
            .sorted(by: ordered)
    }

    static func carried(into month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> [IncomeOccurrence] {
        let late = overdue(before: month, snapshot: snapshot, today: today)
        let dueThisMonth = early(in: month, snapshot: snapshot, today: today).filter { $0.status == .pending }
        return (late + dueThisMonth).sorted(by: ordered)
    }

    private static func early(in month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> [IncomeOccurrence] {
        occurrences(in: month.next, snapshot: snapshot, today: today).filter { $0.dueDate.yearMonth <= month }
    }

    static func summary(for month: YearMonth, snapshot: IncomeSnapshot, today: CalendarDay) -> MonthSummary {
        let own = occurrences(in: month, snapshot: snapshot, today: today)
        let carried = month == today.yearMonth ? carried(into: month, snapshot: snapshot, today: today) : []
        let open = (own + carried).filter { $0.status != .received }
        let received = own.compactMap(\.receipt?.amount).reduce(0, +)
        let remaining = open.map(\.expectedAmount).reduce(0, +)
        let upcoming = (own + occurrences(in: month.next, snapshot: snapshot, today: today))
            .filter { $0.status == .pending && $0.dueDate >= today }
            .sorted(by: ordered)

        return MonthSummary(
            received: received,
            remaining: remaining,
            expected: received + remaining,
            overdueCount: open.filter { $0.status == .overdue }.count,
            next: upcoming.first
        )
    }

    private static func isActive(_ income: Income, in month: YearMonth) -> Bool {
        guard let start = income.startMonth, start <= month else { return false }
        return income.endMonth.map { month <= $0 } ?? true
    }

    private static func amount(for income: Income, in month: YearMonth, snapshot: IncomeSnapshot) -> Decimal? {
        snapshot.amounts
            .filter { $0.incomeID == income.id && $0.validFrom <= month }
            .max { $0.validFrom < $1.validFrom }?
            .amount
    }

    private static func months(of income: Income, before month: YearMonth) -> [YearMonth] {
        switch income.kind {
        case .oneOff:
            guard let date = income.oneOffDate, date.yearMonth < month else { return [] }
            return [date.yearMonth]
        case .fixed, .hourly:
            guard let start = income.startMonth else { return [] }
            let last = min(month.previous, income.endMonth ?? month.previous)
            return YearMonth.range(from: start, through: last)
        }
    }

    private static func ordered(_ lhs: IncomeOccurrence, _ rhs: IncomeOccurrence) -> Bool {
        (lhs.dueDate, lhs.income.name) < (rhs.dueDate, rhs.income.name)
    }

    private static func makeOccurrence(
        _ income: Income,
        _ month: YearMonth,
        dueDate: CalendarDay,
        expected: Decimal,
        receipt: IncomeReceipt?,
        today: CalendarDay,
        reference: YearMonth? = nil,
        businessDays: Int? = nil,
        rate: Decimal? = nil
    ) -> IncomeOccurrence {
        let status: OccurrenceStatus = receipt != nil ? .received : (dueDate < today ? .overdue : .pending)
        return IncomeOccurrence(
            income: income,
            month: month,
            referenceMonth: reference,
            dueDate: dueDate,
            expectedAmount: expected,
            businessDays: businessDays,
            hourlyRate: rate,
            receipt: receipt,
            status: status
        )
    }
}
