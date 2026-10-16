import SwiftUI

struct RootView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
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
}
