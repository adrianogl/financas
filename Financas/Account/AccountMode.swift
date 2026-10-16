enum AccountMode: CaseIterable, Identifiable {
    case signIn
    case signUp

    var id: Self { self }

    var label: String {
        switch self {
        case .signIn: "Entrar"
        case .signUp: "Criar conta"
        }
    }

    var title: String {
        switch self {
        case .signIn: "Entre na sua conta"
        case .signUp: "Crie sua conta"
        }
    }
}
