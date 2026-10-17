import SwiftUI

struct RootView: View {
    @Environment(AccountManager.self) private var account
    @Environment(LockManager.self) private var lockManager
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(AvatarStore.self) private var avatarStore
    @Environment(ReminderScheduler.self) private var reminders
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch account.state {
            case .loading:
                LoadingView()
            case .signedOut:
                AccountView()
            case .awaitingConfirmation(let email):
                ConfirmEmailView(email: email)
            case .recoveringPassword:
                NewPasswordView()
            case .signedIn:
                lockedContent
            }
        }
        .animation(.smooth(duration: 0.35), value: account.state)
        .task(id: account.state) {
            switch account.state {
            case .signedIn(let user):
                await avatarStore.sync(user: user)
            case .signedOut:
                avatarStore.reset()
            case .loading, .awaitingConfirmation, .recoveringPassword:
                break
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lockManager.didEnterBackground()
                BackgroundRefresh.schedule()
            case .active:
                lockManager.willEnterForeground()
                Task { await syncReminders() }
            default:
                break
            }
        }
    }

    private var lockedContent: some View {
        ZStack {
            if lockManager.needsSetup {
                SetupView()
                    .transition(.opacity)
            } else if lockManager.showsHome {
                MainTabView()
                    .blur(radius: lockManager.isUnlocked ? 0 : 28)
                    .allowsHitTesting(lockManager.isUnlocked)
                    .task(id: lockManager.isUnlocked) {
                        guard lockManager.isUnlocked else { return }
                        async let user: Void = account.refreshUser()
                        await incomeStore.refresh()
                        await syncReminders()
                        await user
                    }
                    .onChange(of: incomeStore.snapshot) {
                        Task { await syncReminders() }
                    }
                    .onChange(of: incomeStore.today) {
                        Task { await syncReminders() }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                        Task { await incomeStore.refresh() }
                    }
            }

            switch lockManager.phase {
            case .locked:
                LockView()
                    .transition(.opacity)
            case .biometric:
                BiometricVeilView(biometry: lockManager.biometry)
                    .transition(.opacity)
            case .pin:
                PINEntryView()
                    .transition(.opacity)
            case .unlocked:
                EmptyView()
            }

            if lockManager.isUnlocked && scenePhase != .active {
                PrivacyCoverView()
            }
        }
        .animation(.smooth(duration: 0.35), value: lockManager.phase)
    }

    private func syncReminders() async {
        guard let mode = ReminderSyncMode.current(phase: scenePhase, isUnlocked: lockManager.isUnlocked) else { return }
        incomeStore.moveToday()
        guard incomeStore.dueItems != nil else { return }
        if mode.asksPermission {
            await reminders.requestPermissionIfNeeded(hasIncomes: !incomeStore.snapshot.incomes.isEmpty)
        }
        guard let items = incomeStore.dueItems else { return }
        await reminders.reschedule(items: items, settings: incomeStore.snapshot.settings, clearingDelivered: mode.clearingDelivered)
    }
}
