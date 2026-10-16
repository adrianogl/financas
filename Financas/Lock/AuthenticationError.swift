enum AuthenticationError: Error, Equatable {
    case cancelled
    case fallback
    case unavailable
    case timedOut
    case failed

    var message: String? {
        switch self {
        case .cancelled, .fallback:
            nil
        case .unavailable:
            "Ative a biometria ou um código no iPhone para proteger o app."
        case .timedOut:
            "A biometria não reconheceu a tempo. Tente de novo."
        case .failed:
            "Não foi possível confirmar sua identidade. Tente de novo."
        }
    }
}
