import SwiftUI

@main
struct FinancasApp: App {
    @State private var lockManager: LockManager
    @State private var accountManager: AccountManager
    @State private var incomeStore: IncomeStore
    @State private var avatarStore: AvatarStore

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
        let account = AccountManager(
            service: SupabaseAccountService(client: client),
            hasDevicePIN: { lock.hasPIN },
            onAuthenticated: { lock.beginAfterAccountLogin() },
            onSignedOut: {
                lock.resetForSignOut()
                incomes.reset()
            }
        )
        _accountManager = State(initialValue: account)
        _avatarStore = State(initialValue: AvatarStore(
            service: SupabaseAvatarService(client: client),
            cache: .standard
        ) { version throws(AccountError) in
            try await account.updateAvatarVersion(version)
        })
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lockManager)
                .environment(accountManager)
                .environment(incomeStore)
                .environment(avatarStore)
                .task { await accountManager.start() }
                .onOpenURL { url in
                    Task { await accountManager.handle(url: url) }
                }
        }
    }
}
