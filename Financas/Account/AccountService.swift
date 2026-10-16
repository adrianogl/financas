import Foundation

@MainActor
protocol AccountService {
    func currentUser() -> AccountUser?
    func events() -> AsyncStream<AccountEvent>
    func signUp(name: String, email: String, password: String) async throws(AccountError) -> AccountUser?
    func signIn(email: String, password: String) async throws(AccountError) -> AccountUser
    func sendPasswordReset(email: String) async throws(AccountError)
    func handle(url: URL) async throws(AccountError)
    func updatePassword(_ password: String) async throws(AccountError)
    func signOut(scope: SignOutScope) async
}
