import Foundation

struct IncomeOccurrence: Identifiable, Hashable {
    let income: Income
    let month: YearMonth
    let referenceMonth: YearMonth?
    let dueDate: CalendarDay
    let expectedAmount: Decimal
    let businessDays: Int?
    let hourlyRate: Decimal?
    let receipt: IncomeReceipt?
    let status: OccurrenceStatus

    var id: String {
        "\(income.id)-\(month.year)-\(month.month)"
    }
}
