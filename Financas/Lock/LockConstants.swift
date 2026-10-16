import Foundation
import LocalAuthentication

enum LockConstants {
    static let relockInterval: TimeInterval = 30
    static let biometricTimeout: Duration = .seconds(10)
    static let pinLength = 4
    static let attemptsPerRound = 5
    static let baseLockout: TimeInterval = 30
    static let saltLength = 16

    static let keychainService = "dev.aglv.financas.pin"
    static let keychainAccount = "pin"
    static let failedAttemptsKey = "lock.failedAttempts"
    static let lockedUntilKey = "lock.lockedUntil"
    static let installMarkerKey = "lock.installMarker"

    static let authenticationReason = "Desbloquear seus dados financeiros"
    static let fallbackTitle = "Usar PIN"
    static let wrongPINMessage = "PIN incorreto."

    static let cancellationCodes: Set<LAError.Code> = [.userCancel, .systemCancel, .appCancel]
    static let unavailableCodes: Set<LAError.Code> = [.biometryNotAvailable, .biometryNotEnrolled, .biometryLockout, .passcodeNotSet]

    static let keypadRows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]
}
