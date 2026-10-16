import Foundation
import Observation

@MainActor
@Observable
final class LockManager {
    private(set) var phase: LockPhase = .locked
    private(set) var hasPIN: Bool
    private(set) var biometry: BiometryKind
    private(set) var errorMessage: String?
    private(set) var pinMessage: String?
    private(set) var rejectedPINCount = 0
    private(set) var lockedUntil: Date?
    private(set) var shouldAutoUnlock = true

    private let authenticator: Authenticator
    private let pinStore: PINStore
    private let relockInterval: TimeInterval
    private let now: () -> Date
    private var backgroundedAt: Date?

    init(
        authenticator: Authenticator,
        pinStore: PINStore,
        relockInterval: TimeInterval = LockConstants.relockInterval,
        now: @escaping () -> Date = Date.init
    ) {
        self.authenticator = authenticator
        self.pinStore = pinStore
        self.relockInterval = relockInterval
        self.now = now
        hasPIN = pinStore.hasPIN
        biometry = authenticator.availableBiometry
        lockedUntil = pinStore.lockedUntil
    }

    var isUnlocked: Bool { phase == .unlocked }
    var needsSetup: Bool { isUnlocked && !hasPIN }
    var showsHome: Bool { phase == .biometric || phase == .unlocked }

    func autoUnlockIfNeeded() {
        guard shouldAutoUnlock, phase == .locked else { return }
        shouldAutoUnlock = false
        Task { await unlock() }
    }

    func unlock() async {
        guard phase == .locked || phase == .pin else { return }
        let origin = phase
        shouldAutoUnlock = false
        errorMessage = nil
        biometry = authenticator.availableBiometry

        if hasPIN && biometry == .none {
            phase = .pin
            return
        }

        phase = .biometric
        do {
            try await authenticator.authenticate(
                reason: LockConstants.authenticationReason,
                allowsDevicePasscode: !hasPIN
            )
            resetPINAttempts()
            pinMessage = nil
            phase = .unlocked
        } catch {
            handleBiometricFailure(error, origin: origin)
        }
    }

    func submitPIN(_ pin: String) {
        guard phase == .pin, lockoutRemaining(at: now()) == nil else { return }

        if pinStore.matches(pin) {
            resetPINAttempts()
            pinMessage = nil
            phase = .unlocked
            return
        }

        pinStore.failedAttempts += 1
        if let duration = PINLockoutPolicy.lockoutDuration(afterFailedAttempts: pinStore.failedAttempts) {
            let until = now().addingTimeInterval(duration)
            pinStore.lockedUntil = until
            lockedUntil = until
        }
        pinMessage = LockConstants.wrongPINMessage
        rejectedPINCount += 1
    }

    func lockoutRemaining(at date: Date) -> TimeInterval? {
        guard let lockedUntil, lockedUntil > date else { return nil }
        return lockedUntil.timeIntervalSince(date)
    }

    func createPIN(_ pin: String) throws(PINStoreError) {
        try pinStore.save(pin)
        hasPIN = true
    }

    func lock() {
        lock(autoUnlock: false)
    }

    func beginAfterAccountLogin() {
        shouldAutoUnlock = false
        errorMessage = nil
        pinMessage = nil
        phase = .unlocked
    }

    func resetForSignOut() {
        pinStore.clear()
        hasPIN = false
        resetPINAttempts()
        lock(autoUnlock: false)
    }

    func didEnterBackground() {
        backgroundedAt = now()
    }

    func willEnterForeground() {
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        if phase == .unlocked && now().timeIntervalSince(backgroundedAt) >= relockInterval {
            lock(autoUnlock: true)
        }
    }

    private func lock(autoUnlock: Bool) {
        phase = .locked
        backgroundedAt = nil
        shouldAutoUnlock = autoUnlock
        errorMessage = nil
        pinMessage = nil
        biometry = authenticator.availableBiometry
    }

    private func handleBiometricFailure(_ error: AuthenticationError, origin: LockPhase) {
        if hasPIN {
            phase = .pin
        } else if error == .unavailable {
            phase = .unlocked
        } else {
            errorMessage = error.message
            phase = origin
        }
    }

    private func resetPINAttempts() {
        pinStore.failedAttempts = 0
        pinStore.lockedUntil = nil
        lockedUntil = nil
    }
}
