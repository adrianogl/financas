import SwiftUI

@main
struct FinancasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var lockManager: LockManager
    @State private var accountManager: AccountManager
    @State private var incomeStore: IncomeStore
    @State private var avatarStore: AvatarStore
    @State private var reminders: ReminderScheduler

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
        let scheduler = ReminderScheduler(center: SystemReminderCenter())

        _lockManager = State(initialValue: lock)
        _incomeStore = State(initialValue: incomes)
        _reminders = State(initialValue: scheduler)
        let account = AccountManager(
            service: SupabaseAccountService(client: client),
            hasDevicePIN: { lock.hasPIN },
            onAuthenticated: { lock.beginAfterAccountLogin() },
            onSignedOut: {
                lock.resetForSignOut()
                incomes.reset()
                Task { await scheduler.reset() }
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
                .environment(reminders)
                .environment(appDelegate.router)
                .task { await accountManager.start() }
                .onOpenURL { url in
                    Task { await accountManager.handle(url: url) }
                }
        }
        .backgroundTask(.appRefresh(ReminderConstants.refreshTaskID)) {
            await refreshReminders()
        }
    }

    @MainActor
    private func refreshReminders() async {
        BackgroundRefresh.schedule()
        await incomeStore.refresh()
        if let items = incomeStore.dueItems {
            await reminders.reschedule(items: items, clearingDelivered: false)
        }
    }
}
