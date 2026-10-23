extension AppTab {
    var title: String {
        switch self {
        case .home:
            "Início"
        case .incomes:
            "Receitas"
        case .expenses:
            "Despesas"
        case .cards:
            "Cartões"
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
        case .cards:
            "creditcard"
        case .overdue:
            "bell.badge"
        }
    }
}
