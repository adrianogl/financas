enum ExpensePartOrigin: Hashable {
    case paid
    case bill
    case fixed
    case average(months: [YearMonth])
    case estimated
}
