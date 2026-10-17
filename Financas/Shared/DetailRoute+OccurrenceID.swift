extension DetailRoute {
    var occurrenceID: String {
        switch self {
        case .income(let id, _), .expense(let id, _):
            id
        }
    }
}
