enum DetailRoute: Hashable {
    case income(id: String, month: YearMonth)
    case expense(id: String, month: YearMonth)
}
