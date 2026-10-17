enum IncomeKind: String, Codable, Sendable {
    case fixed
    case hourly
    case oneOff = "one_off"
}
