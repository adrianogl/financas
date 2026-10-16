import Foundation
import Testing
@testable import Financas

@MainActor
struct LockManagerTests {
    private func makeManager(
        authenticator: FakeAuthenticator = FakeAuthenticator(),
        pinStore: FakePINStore = FakePINStore(pin: "1234"),
        clock: FakeClock = FakeClock()
    ) -> LockManager {
        LockManager(authenticator: authenticator, pinStore: pinStore, relockInterval: 30, now: { clock.date })
    }

    @Test func unlocksWhenFaceIDSucceeds() async {
        let manager = makeManager()

        await manager.unlock()

        #expect(manager.phase == .unlocked)
        #expect(!manager.needsSetup)
    }

    @Test func goesToPINWhenFaceIDFails() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)))

        await manager.unlock()

        #expect(manager.phase == .pin)
    }

    @Test func goesToPINWhenUserAsksForFallback() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.fallback)))

        await manager.unlock()

        #expect(manager.phase == .pin)
    }

    @Test func goesToPINWhenUserCancelsFaceID() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.cancelled)))

        await manager.unlock()

        #expect(manager.phase == .pin)
    }

    @Test func goesToPINWhenFaceIDTimesOut() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.timedOut)))

        await manager.unlock()

        #expect(manager.phase == .pin)
    }

    @Test func firstUseTimeoutStaysLockedWithMessage() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.timedOut)), pinStore: FakePINStore())

        await manager.unlock()

        #expect(manager.phase == .locked)
        #expect(manager.errorMessage == AuthenticationError.timedOut.message)
    }

    @Test func firstUseCancelReturnsToLockScreenWithoutMessage() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.cancelled)), pinStore: FakePINStore())

        await manager.unlock()

        #expect(manager.phase == .locked)
        #expect(manager.errorMessage == nil)
    }

    @Test func staysOnPINWhenFaceIDRetryIsCancelled() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed), .failure(.cancelled)))
        await manager.unlock()

        await manager.unlock()

        #expect(manager.phase == .pin)
    }

    @Test func firstUseAllowsDevicePasscodeAndThenNeedsSetup() async {
        let authenticator = FakeAuthenticator()
        let manager = makeManager(authenticator: authenticator, pinStore: FakePINStore())

        await manager.unlock()

        #expect(authenticator.passcodeAllowances == [true])
        #expect(manager.needsSetup)
    }

    @Test func withPINFaceIDDoesNotAllowDevicePasscode() async {
        let authenticator = FakeAuthenticator()
        let manager = makeManager(authenticator: authenticator)

        await manager.unlock()

        #expect(authenticator.passcodeAllowances == [false])
    }

    @Test func firstUseFailureStaysLockedWithMessage() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)), pinStore: FakePINStore())

        await manager.unlock()

        #expect(manager.phase == .locked)
        #expect(manager.errorMessage == AuthenticationError.failed.message)
    }

    @Test func createPINFinishesSetup() async throws {
        let pinStore = FakePINStore()
        let manager = makeManager(pinStore: pinStore)
        await manager.unlock()

        try manager.createPIN("4321")

        #expect(!manager.needsSetup)
        #expect(pinStore.pin == "4321")
    }

    @Test func correctPINUnlocks() async {
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)))
        await manager.unlock()

        manager.submitPIN("1234")

        #expect(manager.phase == .unlocked)
    }

    @Test func wrongPINShowsMessageAndCountsAttempt() async {
        let pinStore = FakePINStore(pin: "1234")
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)), pinStore: pinStore)
        await manager.unlock()

        manager.submitPIN("0000")

        #expect(manager.phase == .pin)
        #expect(manager.pinMessage == LockConstants.wrongPINMessage)
        #expect(manager.rejectedPINCount == 1)
        #expect(pinStore.failedAttempts == 1)
    }

    @Test func fiveWrongPINsLockKeypadForThirtySeconds() async {
        let clock = FakeClock()
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)), clock: clock)
        await manager.unlock()

        for _ in 0..<5 { manager.submitPIN("0000") }
        manager.submitPIN("1234")

        #expect(manager.phase == .pin)
        #expect(manager.lockoutRemaining(at: clock.date) == 30)

        clock.advance(by: 30)
        manager.submitPIN("1234")

        #expect(manager.phase == .unlocked)
    }

    @Test func correctPINResetsAttempts() async {
        let pinStore = FakePINStore(pin: "1234")
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)), pinStore: pinStore)
        await manager.unlock()
        manager.submitPIN("0000")

        manager.submitPIN("1234")

        #expect(pinStore.failedAttempts == 0)
    }

    @Test func faceIDRetryFromPINUnlocksAndKeepsPIN() async {
        let pinStore = FakePINStore(pin: "1234")
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed), .success(())), pinStore: pinStore)
        await manager.unlock()

        await manager.unlock()

        #expect(manager.phase == .unlocked)
        #expect(pinStore.pin == "1234")
    }

    @Test func touchIDDeviceUsesTouchID() async {
        let manager = makeManager(authenticator: FakeAuthenticator(biometry: .touchID))

        await manager.unlock()

        #expect(manager.biometry == .touchID)
        #expect(manager.phase == .unlocked)
    }

    @Test func deviceWithoutBiometryGoesStraightToPIN() async {
        let authenticator = FakeAuthenticator(biometry: .none)
        let manager = makeManager(authenticator: authenticator)

        await manager.unlock()

        #expect(manager.phase == .pin)
        #expect(authenticator.passcodeAllowances.isEmpty)
    }

    @Test func deviceWithoutBiometryUsesDevicePasscodeOnFirstUse() async {
        let authenticator = FakeAuthenticator(biometry: .none)
        let manager = makeManager(authenticator: authenticator, pinStore: FakePINStore())

        await manager.unlock()

        #expect(authenticator.passcodeAllowances == [true])
        #expect(manager.needsSetup)
    }

    @Test func deviceWithoutAnyProtectionGoesToSetupOnFirstUse() async {
        let manager = makeManager(authenticator: FakeAuthenticator(biometry: .none, .failure(.unavailable)), pinStore: FakePINStore())

        await manager.unlock()

        #expect(manager.needsSetup)
    }

    @Test func manualLockWaitsForTap() async {
        let manager = makeManager()
        await manager.unlock()

        manager.lock()

        #expect(manager.phase == .locked)
        #expect(!manager.shouldAutoUnlock)
    }

    @Test func autoUnlockIsIgnoredAfterManualLock() async {
        let authenticator = FakeAuthenticator()
        let manager = makeManager(authenticator: authenticator)
        await manager.unlock()
        manager.lock()

        manager.autoUnlockIfNeeded()
        await Task.yield()

        #expect(manager.phase == .locked)
        #expect(authenticator.passcodeAllowances.count == 1)
    }

    @Test func relockFromBackgroundUnlocksAutomatically() async {
        let clock = FakeClock()
        let manager = makeManager(clock: clock)
        await manager.unlock()

        manager.didEnterBackground()
        clock.advance(by: 30)
        manager.willEnterForeground()

        #expect(manager.shouldAutoUnlock)
    }

    @Test func afterLoginWithoutPINGoesToSetupWithoutBiometry() {
        let authenticator = FakeAuthenticator()
        let manager = makeManager(authenticator: authenticator, pinStore: FakePINStore())

        manager.beginAfterAccountLogin()

        #expect(manager.needsSetup)
        #expect(authenticator.passcodeAllowances.isEmpty)
    }

    @Test func afterLoginWithPINGoesHome() {
        let manager = makeManager()

        manager.beginAfterAccountLogin()

        #expect(manager.phase == .unlocked)
        #expect(!manager.needsSetup)
        #expect(!manager.shouldAutoUnlock)
    }

    @Test func signOutResetClearsPIN() async {
        let pinStore = FakePINStore(pin: "1234")
        let clock = FakeClock()
        let manager = makeManager(authenticator: FakeAuthenticator(.failure(.failed)), pinStore: pinStore, clock: clock)
        await manager.unlock()
        for _ in 0..<5 { manager.submitPIN("0000") }

        manager.resetForSignOut()

        #expect(pinStore.pin == nil)
        #expect(!manager.hasPIN)
        #expect(manager.phase == .locked)
        #expect(!manager.shouldAutoUnlock)
        #expect(manager.lockoutRemaining(at: clock.date) == nil)
    }

    @Test func relocksAfterThirtySecondsInBackground() async {
        let clock = FakeClock()
        let manager = makeManager(clock: clock)
        await manager.unlock()

        manager.didEnterBackground()
        clock.advance(by: 30)
        manager.willEnterForeground()

        #expect(manager.phase == .locked)
    }

    @Test func staysUnlockedAfterShortBackground() async {
        let clock = FakeClock()
        let manager = makeManager(clock: clock)
        await manager.unlock()

        manager.didEnterBackground()
        clock.advance(by: 29)
        manager.willEnterForeground()

        #expect(manager.phase == .unlocked)
    }
}
