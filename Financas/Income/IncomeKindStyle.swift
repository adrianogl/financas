extension IncomeKind {
    var title: String {
        switch self {
        case .fixed: "Fixa"
        case .hourly: "Por hora"
        case .oneOff: "Avulsa"
        }
    }
}
