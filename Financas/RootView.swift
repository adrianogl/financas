import SwiftUI

struct RootView: View {
    @Environment(AccountManager.self) private var account
    @Environment(LockManager.self) private var lockManager
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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                lockManager.didEnterBackground()
            case .active:
                lockManager.willEnterForeground()
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
                HomeView()
                    .blur(radius: lockManager.isUnlocked ? 0 : 28)
                    .allowsHitTesting(lockManager.isUnlocked)
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
}
