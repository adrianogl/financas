import Foundation

enum IncomeConstants {
    static let fixedHolidays: [(month: Int, day: Int)] = [
        (1, 1), (4, 21), (5, 1), (9, 7), (10, 12), (11, 2), (11, 15), (11, 20), (12, 25),
    ]
    static let easterOffsets = [-48, -47, -2, 60]
    static let incomesTable = "incomes"
    static let amountsTable = "income_amounts"
    static let receiptsTable = "income_receipts"
    static let defaultHoursPerDay: Decimal = 8
    static let currencyCode = "BRL"
}
