import Foundation
@testable import Financas

@MainActor
final class FakeAuthenticator: Authenticator {
    private var results: [Result<Void, AuthenticationError>]
    private(set) var passcodeAllowances: [Bool] = []
    var availableBiometry: BiometryKind

    init(biometry: BiometryKind = .faceID, _ results: Result<Void, AuthenticationError>...) {
        availableBiometry = biometry
        self.results = results
    }

    func authenticate(reason: String, allowsDevicePasscode: Bool) async throws(AuthenticationError) {
        passcodeAllowances.append(allowsDevicePasscode)
        let result = results.isEmpty ? .success(()) : results.removeFirst()
        try result.get()
    }
}

@MainActor
final class FakePINStore: PINStore {
    var pin: String?
    var failedAttempts = 0
    var lockedUntil: Date?

    init(pin: String? = nil) {
        self.pin = pin
    }

    var hasPIN: Bool { pin != nil }

    func save(_ pin: String) throws(PINStoreError) {
        self.pin = pin
    }

    func matches(_ pin: String) -> Bool {
        self.pin == pin
    }

    func clear() {
        pin = nil
        failedAttempts = 0
        lockedUntil = nil
    }
}

@MainActor
final class FakeClock {
    private(set) var date = Date(timeIntervalSince1970: 0)

    func advance(by interval: TimeInterval) {
        date += interval
    }
}
