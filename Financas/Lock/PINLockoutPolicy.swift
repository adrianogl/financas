import Foundation

enum PINLockoutPolicy {
    static func lockoutDuration(afterFailedAttempts attempts: Int) -> TimeInterval? {
        guard attempts > 0, attempts.isMultiple(of: LockConstants.attemptsPerRound) else { return nil }
        let round = attempts / LockConstants.attemptsPerRound
        return LockConstants.baseLockout * pow(2, Double(round - 1))
    }
}
