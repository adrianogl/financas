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
    var hasValidSession = true
    var signUpResult: Result<AccountUser?, AccountError> = .success(nil)
    var signInResult: Result<AccountUser, AccountError> = .success(.sample)
    var resetResult: Result<Void, AccountError> = .success(())
    var handleResult: Result<AccountUser, AccountError> = .success(.sample)
    var updateResult: Result<Void, AccountError> = .success(())
    var suspendsSignIn = false
    var refreshResult: Result<AccountUser, AccountError> = .success(.sample)
    var avatarUpdateResult: Result<Void, AccountError> = .success(())
    private(set) var updatedAvatarVersions: [Int?] = []

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

    func hasSession() async -> Bool { hasValidSession }

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

    func refreshUser() async throws(AccountError) -> AccountUser {
        try refreshResult.get()
    }

    func updateAvatarVersion(_ version: Int?) async throws(AccountError) -> AccountUser {
        updatedAvatarVersions.append(version)
        try avatarUpdateResult.get()
        var user = storedUser ?? .sample
        user.avatarVersion = version
        return user
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
    private(set) var savedSettings: [(settings: AccountSettings, previous: AccountSettings)] = []
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

    func saveSettings(_ settings: AccountSettings, previous: AccountSettings) async throws(IncomeError) {
        try await respond("saveSettings")
        savedSettings.append((settings, previous))
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

@MainActor
final class FakeExpenseService: ExpenseService {
    var snapshot: ExpenseSnapshot
    var nextError: IncomeError?
    var holdsResponses = false
    private(set) var calls: [String] = []
    private(set) var lastSavedParts: [ExpensePart] = []
    private(set) var lastSavedPartTerms: [ExpensePartTerm] = []
    private var pending: [CheckedContinuation<Void, Never>] = []

    init(snapshot: ExpenseSnapshot = ExpenseSamples.snapshot) {
        self.snapshot = snapshot
    }

    func release() {
        holdsResponses = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    func load() async throws(IncomeError) -> ExpenseSnapshot {
        try await respond("load")
        return snapshot
    }

    func save(
        _ expense: Expense,
        term: ExpenseTerm?,
        parts: [ExpensePart],
        partTerms: [ExpensePartTerm]
    ) async throws(IncomeError) {
        lastSavedParts = parts
        lastSavedPartTerms = partTerms
        try await respond("saveExpense")
    }

    func delete(expenseID: UUID) async throws(IncomeError) {
        try await respond("deleteExpense")
    }

    func save(_ bill: ExpenseBill) async throws(IncomeError) {
        try await respond("saveBill")
    }

    func deleteBill(id: UUID) async throws(IncomeError) {
        try await respond("deleteBill")
    }

    func save(_ entry: ExpenseEntry) async throws(IncomeError) {
        try await respond("saveEntry")
    }

    func deleteEntry(id: UUID) async throws(IncomeError) {
        try await respond("deleteEntry")
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

@MainActor
final class FakeAvatarService: AvatarService {
    var files: [Int: Data] = [:]
    var nextError: AvatarError?
    var holdsResponses = false
    private(set) var uploads: [(version: Int, data: Data)] = []
    private(set) var downloadedVersions: [Int] = []
    private(set) var removedVersions: [Int] = []
    private var pending: [CheckedContinuation<Void, Never>] = []

    func release() {
        holdsResponses = false
        pending.forEach { $0.resume() }
        pending.removeAll()
    }

    func upload(_ data: Data, userID: String, version: Int) async throws(AvatarError) {
        uploads.append((version, data))
        try await respond()
        files[version] = data
    }

    func download(userID: String, version: Int) async throws(AvatarError) -> Data {
        downloadedVersions.append(version)
        try await respond()
        guard let data = files[version] else { throw .unknown }
        return data
    }

    func remove(userID: String, version: Int) async throws(AvatarError) {
        removedVersions.append(version)
        try await respond()
        files[version] = nil
    }

    private func respond() async throws(AvatarError) {
        if holdsResponses {
            await withCheckedContinuation { pending.append($0) }
        }
        if let error = nextError {
            nextError = nil
            throw error
        }
    }
}

@MainActor
final class AvatarVersionRecorder {
    var versions: [Int?] = []
    var error: AccountError?
}

@MainActor
final class FakeReminderCenter: ReminderCenter {
    var status: ReminderAuthorization
    var grantsOnRequest: Bool
    private(set) var requests = 0
    private(set) var pending: [Reminder] = []
    private(set) var replaceCalls = 0
    private(set) var deliveredRemoved = 0
    private(set) var removedAll = 0
    private(set) var replaceLog: [String] = []
    var replaceSuspensions = 0

    init(status: ReminderAuthorization = .notDetermined, grantsOnRequest: Bool = true) {
        self.status = status
        self.grantsOnRequest = grantsOnRequest
    }

    func authorization() async -> ReminderAuthorization { status }

    func requestAuthorization() async -> Bool {
        requests += 1
        status = grantsOnRequest ? .allowed : .denied
        return grantsOnRequest
    }

    func replacePending(with reminders: [Reminder]) async {
        replaceCalls += 1
        replaceLog.append("start")
        for _ in 0..<replaceSuspensions {
            await Task.yield()
        }
        pending = reminders
        replaceLog.append("end")
    }

    func removeDelivered() async { deliveredRemoved += 1 }

    func removeAll() async {
        removedAll += 1
        pending = []
    }
}
