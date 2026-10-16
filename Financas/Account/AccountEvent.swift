enum AccountEvent: Equatable, Sendable {
    case signedOut
    case passwordRecovery(AccountUser)
}
