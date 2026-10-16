import SwiftUI

@main
struct FinancasApp: App {
    @State private var lockManager = LockManager(
        authenticator: BiometricAuthenticator(),
        pinStore: KeychainPINStore()
    )

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(lockManager)
        }
    }
}
