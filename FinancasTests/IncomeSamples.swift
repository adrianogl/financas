import Foundation
@testable import Financas

enum IncomeSamples {
    static func money(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    static func month(_ year: Int, _ month: Int) -> YearMonth {
        YearMonth(year: year, month: month)
    }

    static func day(_ year: Int, _ month: Int, _ day: Int) -> CalendarDay {
        CalendarDay(year: year, month: month, day: day)
    }

    static let today = day(2026, 10, 16)

    static let fixed = Income(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Fixa",
        kind: .fixed,
        dayOfMonth: 1,
        startMonth: month(2026, 10)
    )

    static let hourly = Income(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Por hora",
        kind: .hourly,
        dayOfMonth: 15,
        hoursPerDay: 8,
        startMonth: month(2026, 10)
    )

    static let fixedAmount = IncomeAmount(id: UUID(), incomeID: fixed.id, amount: money("13020.04"), validFrom: month(2026, 10))
    static let hourlyRate = IncomeAmount(id: UUID(), incomeID: hourly.id, amount: 90, validFrom: month(2026, 9))

    static let snapshot = IncomeSnapshot(incomes: [fixed, hourly], amounts: [fixedAmount, hourlyRate], receipts: [])

    static func receipt(_ income: Income, _ month: YearMonth, amount: Decimal, on day: CalendarDay = today) -> IncomeReceipt {
        IncomeReceipt(id: UUID(), incomeID: income.id, month: month, receivedOn: day, amount: amount)
    }
}
