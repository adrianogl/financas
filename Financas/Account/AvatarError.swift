enum AvatarError: Error, Equatable {
    case network
    case unknown

    var uploadMessage: String {
        switch self {
        case .network:
            "Sem conexão. Verifique a internet e tente de novo."
        case .unknown:
            "Não foi possível enviar a foto. Tente de novo."
        }
    }

    var removeMessage: String {
        switch self {
        case .network:
            "Sem conexão. Verifique a internet e tente de novo."
        case .unknown:
            "Não foi possível remover a foto. Tente de novo."
        }
    }

    init(_ error: AccountError) {
        self = error == .network ? .network : .unknown
    }
}
