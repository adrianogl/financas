import Foundation
import Supabase

@MainActor
final class SupabaseAccountService: AccountService {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        client = SupabaseClient(
            supabaseURL: config.url,
            supabaseKey: config.key,
            options: SupabaseClientOptions(
                auth: .init(
                    redirectToURL: AccountConstants.redirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }

    func currentUser() -> AccountUser? {
        client.auth.currentUser.map(Self.accountUser)
    }

    func events() -> AsyncStream<AccountEvent> {
        let changes = client.auth.authStateChanges
        return AsyncStream { continuation in
            let task = Task {
                for await (event, session) in changes {
                    switch event {
                    case .signedOut:
                        continuation.yield(.signedOut)
                    case .passwordRecovery:
                        if let session {
                            continuation.yield(.passwordRecovery(Self.accountUser(from: session.user)))
                        }
                    default:
                        break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func signUp(name: String, email: String, password: String) async throws(AccountError) -> AccountUser? {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: [AccountConstants.nameMetadataKey: .string(name)],
                redirectTo: AccountConstants.redirectURL
            )
            switch response {
            case .session(let session):
                return Self.accountUser(from: session.user)
            case .user:
                return nil
            }
        } catch {
            throw Self.accountError(from: error)
        }
    }

    func signIn(email: String, password: String) async throws(AccountError) -> AccountUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return Self.accountUser(from: session.user)
        } catch {
            throw Self.accountError(from: error)
        }
    }

    func sendPasswordReset(email: String) async throws(AccountError) {
        do {
            try await client.auth.resetPasswordForEmail(email, redirectTo: AccountConstants.redirectURL)
        } catch {
            throw Self.accountError(from: error)
        }
    }

    func handle(url: URL) async throws(AccountError) {
        do {
            _ = try await client.auth.session(from: url)
        } catch {
            throw .invalidRecoveryLink
        }
    }

    func updatePassword(_ password: String) async throws(AccountError) {
        do {
            _ = try await client.auth.update(user: UserAttributes(password: password))
        } catch {
            throw Self.accountError(from: error)
        }
    }

    func signOut(scope: Financas.SignOutScope) async {
        try? await client.auth.signOut(scope: scope == .local ? .local : .others)
    }

    nonisolated private static func accountUser(from user: User) -> AccountUser {
        AccountUser(
            id: user.id.uuidString,
            email: user.email ?? "",
            name: user.userMetadata[AccountConstants.nameMetadataKey]?.stringValue ?? ""
        )
    }

    private static func accountError(from error: any Error) -> AccountError {
        if error is URLError {
            return .network
        }
        guard let authError = error as? AuthError else { return .unknown }

        switch authError {
        case .weakPassword:
            return .weakPassword
        case .api(_, let errorCode, _, _):
            switch errorCode {
            case .invalidCredentials: return .invalidCredentials
            case .emailNotConfirmed: return .emailNotConfirmed
            case .userAlreadyExists, .emailExists: return .emailAlreadyRegistered
            case .weakPassword: return .weakPassword
            default: return .unknown
            }
        default:
            return .unknown
        }
    }
}
