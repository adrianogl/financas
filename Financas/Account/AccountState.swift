enum AccountState: Equatable {
    case loading
    case signedOut
    case awaitingConfirmation(email: String)
    case recoveringPassword(AccountUser)
    case signedIn(AccountUser)
}
