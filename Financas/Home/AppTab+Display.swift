extension AppTab {
    var title: String {
        switch self {
        case .home:
            "Início"
        case .incomes:
            "Receitas"
        case .expenses:
            "Despesas"
        case .overdue:
            "Atrasadas"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            "house"
        case .incomes:
            "arrow.down.circle"
        case .expenses:
            "arrow.up.circle"
        case .overdue:
            "exclamationmark.circle"
        }
    }
}
