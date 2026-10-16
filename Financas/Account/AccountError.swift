enum AccountError: Error, Equatable {
    case invalidCredentials
    case emailNotConfirmed
    case emailAlreadyRegistered
    case weakPassword
    case invalidRecoveryLink
    case invalidConfirmationLink
    case samePassword
    case emailRateLimited
    case network
    case unknown

    var message: String {
        switch self {
        case .invalidCredentials:
            "E-mail ou senha incorretos."
        case .emailNotConfirmed:
            "Confirme seu e-mail antes de entrar. O link está na sua caixa de entrada."
        case .emailAlreadyRegistered:
            "Já existe uma conta com esse e-mail. Entre com ela."
        case .weakPassword:
            "A senha precisa ter pelo menos 8 caracteres."
        case .invalidRecoveryLink:
            "O link expirou ou foi aberto em outro aparelho. Peça um novo neste aparelho."
        case .invalidConfirmationLink:
            "Não foi possível confirmar por este link. Se você já tocou nele, entre com seu e-mail e senha."
        case .samePassword:
            "A nova senha precisa ser diferente da atual."
        case .emailRateLimited:
            "Muitos e-mails enviados em pouco tempo. Espere alguns minutos e tente de novo."
        case .network:
            "Sem conexão. Verifique a internet e tente de novo."
        case .unknown:
            "Algo deu errado. Tente de novo."
        }
    }
}
