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
            "arrow.down.to.line"
        case .expenses:
            "arrow.up.to.line"
        case .overdue:
            "bell.badge"
        }
    }
}
