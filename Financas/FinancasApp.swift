import SwiftUI

@main
struct FinancasApp: App {
    @State private var lockManager: LockManager
    @State private var accountManager: AccountManager

    init() {
        let lock = LockManager(authenticator: BiometricAuthenticator(), pinStore: KeychainPINStore())
        let config: SupabaseConfig
        do {
            config = try SupabaseConfig(info: Bundle.main.infoDictionary ?? [:])
        } catch {
            fatalError("Configure Config/Secrets.xcconfig com a URL e a chave do Supabase.")
        }

        _lockManager = State(initialValue: lock)
        _accountManager = State(initialValue: AccountManager(
            service: SupabaseAccountService(config: config),
            hasDevicePIN: { lock.hasPIN },
            onAuthenticated: { lock.beginAfterAccountLogin() },
            onSignedOut: { lock.resetForSignOut() }
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lockManager)
                .environment(accountManager)
                .task { await accountManager.start() }
                .onOpenURL { url in
                    Task { await accountManager.handle(url: url) }
                }
        }
    }
}
