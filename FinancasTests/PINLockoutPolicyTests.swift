import Testing
@testable import Financas

struct PINLockoutPolicyTests {
    @Test(arguments: [(4, nil), (5, 30), (6, nil), (10, 60), (15, 120)] as [(Int, Double?)])
    func lockoutDoublesEachRound(attempts: Int, expected: Double?) {
        #expect(PINLockoutPolicy.lockoutDuration(afterFailedAttempts: attempts) == expected)
    }
}
