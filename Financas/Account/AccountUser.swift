struct AccountUser: Equatable, Sendable {
    let id: String
    let email: String
    let name: String
    var avatarVersion: Int? = nil
}
