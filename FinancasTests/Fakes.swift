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

extension AccountUser {
    static let sample = AccountUser(id: "u1", email: "eu@mail.com", name: "Adriano")
}

@MainActor
final class FakeAccountService: AccountService {
    var storedUser: AccountUser?
    var signUpResult: Result<AccountUser?, AccountError> = .success(nil)
    var signInResult: Result<AccountUser, AccountError> = .success(.sample)
    var resetResult: Result<Void, AccountError> = .success(())
    var handleResult: Result<AccountUser, AccountError> = .success(.sample)
    var updateResult: Result<Void, AccountError> = .success(())
    var suspendsSignIn = false

    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var signUpCalls: [(name: String, email: String, password: String)] = []
    private(set) var signOutScopes: [SignOutScope] = []
    private(set) var updatedPasswords: [String] = []
    private(set) var handledURLs: [URL] = []

    private let stream: AsyncStream<AccountEvent>
    private let continuation: AsyncStream<AccountEvent>.Continuation
    private var signInGate: CheckedContinuation<Void, Never>?

    init() {
        (stream, continuation) = AsyncStream.makeStream()
    }

    func currentUser() -> AccountUser? { storedUser }

    func events() -> AsyncStream<AccountEvent> { stream }

    func send(_ event: AccountEvent) {
        continuation.yield(event)
    }

    func signUp(name: String, email: String, password: String) async throws(AccountError) -> AccountUser? {
        signUpCalls.append((name, email, password))
        return try signUpResult.get()
    }

    func signIn(email: String, password: String) async throws(AccountError) -> AccountUser {
        signInCalls.append((email, password))
        if suspendsSignIn {
            await withCheckedContinuation { signInGate = $0 }
        }
        return try signInResult.get()
    }

    func releaseSignIn() {
        signInGate?.resume()
        signInGate = nil
    }

    func sendPasswordReset(email: String) async throws(AccountError) {
        try resetResult.get()
    }

    func handle(url: URL) async throws(AccountError) -> AccountUser {
        handledURLs.append(url)
        return try handleResult.get()
    }

    func updatePassword(_ password: String) async throws(AccountError) {
        updatedPasswords.append(password)
        try updateResult.get()
    }

    func signOut(scope: SignOutScope) async {
        signOutScopes.append(scope)
        storedUser = nil
    }
}

@MainActor
final class FakeIncomeService: IncomeService {
    var snapshot: IncomeSnapshot
    var nextError: IncomeError?
    var holdsResponses = false
    private(set) var calls: [String] = []
    private var pending: [CheckedContinuation<Void, Never>] = []

    init(snapshot: IncomeSnapshot = IncomeSamples.snapshot) {
        self.snapshot = snapshot
    }

    func release() {
        holdsResponses = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    func load() async throws(IncomeError) -> IncomeSnapshot {
        try await respond("load")
        return snapshot
    }

    func save(_ income: Income, amount: IncomeAmount?) async throws(IncomeError) {
        try await respond("saveIncome")
    }

    func delete(incomeID: UUID) async throws(IncomeError) {
        try await respond("deleteIncome")
    }

    func save(_ receipt: IncomeReceipt) async throws(IncomeError) {
        try await respond("saveReceipt")
    }

    func deleteReceipt(id: UUID) async throws(IncomeError) {
        try await respond("deleteReceipt")
    }

    private func respond(_ call: String) async throws(IncomeError) {
        calls.append(call)
        if holdsResponses {
            await withCheckedContinuation { pending.append($0) }
        }
        if let error = nextError {
            nextError = nil
            throw error
        }
    }
}
