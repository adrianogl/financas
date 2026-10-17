enum IncomeError: Error, Equatable {
    case network
    case unknown

    var message: String {
        switch self {
        case .network:
            "Sem conexão. Verifique a internet e tente de novo."
        case .unknown:
            "Não foi possível salvar. Tente de novo."
        }
    }
}
