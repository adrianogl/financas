import SwiftUI

@main
struct FinancasApp: App {
    @State private var lockManager: LockManager
    @State private var accountManager: AccountManager
    @State private var incomeStore: IncomeStore

    init() {
        let lock = LockManager(authenticator: BiometricAuthenticator(), pinStore: KeychainPINStore())
        let config: SupabaseConfig
        do {
            config = try SupabaseConfig(info: Bundle.main.infoDictionary ?? [:])
        } catch {
            fatalError("Configure Config/Secrets.xcconfig com a URL e a chave do Supabase.")
        }

        let client = SupabaseClientFactory.make(config: config)
        let incomes = IncomeStore(service: SupabaseIncomeService(client: client))

        _lockManager = State(initialValue: lock)
        _incomeStore = State(initialValue: incomes)
        _accountManager = State(initialValue: AccountManager(
            service: SupabaseAccountService(client: client),
            hasDevicePIN: { lock.hasPIN },
            onAuthenticated: { lock.beginAfterAccountLogin() },
            onSignedOut: {
                lock.resetForSignOut()
                incomes.reset()
            }
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lockManager)
                .environment(accountManager)
                .environment(incomeStore)
                .task { await accountManager.start() }
                .onOpenURL { url in
                    Task { await accountManager.handle(url: url) }
                }
        }
    }
}
