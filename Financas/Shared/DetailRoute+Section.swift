extension DetailRoute {
    var section: AppTab {
        switch self {
        case .income:
            .incomes
        case .expense:
            .expenses
        }
    }
}
