enum BiometryKind: Equatable {
    case none
    case faceID
    case touchID
    case opticID

    var title: String {
        switch self {
        case .none: "Código"
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "lock.open"
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .opticID: "opticid"
        }
    }

    var prompt: String {
        switch self {
        case .none: "Confirme o código do iPhone"
        case .faceID: "Olhe para o iPhone"
        case .touchID: "Toque no sensor de digital"
        case .opticID: "Olhe para o dispositivo"
        }
    }
}
