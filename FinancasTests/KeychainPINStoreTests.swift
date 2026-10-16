import Foundation
import Testing
@testable import Financas

@MainActor
struct KeychainPINStoreTests {
    private func makeStore() -> KeychainPINStore {
        let suite = "KeychainPINStoreTests.\(UUID().uuidString)"
        return KeychainPINStore(defaults: UserDefaults(suiteName: suite)!, service: suite)
    }

    @Test func savesAndMatchesPIN() throws {
        let store = makeStore()
        defer { store.clear() }

        try store.save("1234")

        #expect(store.hasPIN)
        #expect(store.matches("1234"))
        #expect(!store.matches("4321"))
    }

    @Test func replacingPINForgetsOldOne() throws {
        let store = makeStore()
        defer { store.clear() }

        try store.save("1234")
        try store.save("5678")

        #expect(store.matches("5678"))
        #expect(!store.matches("1234"))
    }

    @Test func clearRemovesPINAndAttempts() throws {
        let store = makeStore()
        try store.save("1234")
        store.failedAttempts = 3
        store.lockedUntil = .now

        store.clear()

        #expect(!store.hasPIN)
        #expect(store.failedAttempts == 0)
        #expect(store.lockedUntil == nil)
    }
}
