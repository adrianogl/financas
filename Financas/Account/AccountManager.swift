import Foundation
import Observation

@MainActor
@Observable
final class AccountManager {
    private(set) var state: AccountState = .loading
    private(set) var isWorking = false
    private(set) var errorMessage: String?

    private let service: AccountService
    private let defaults: UserDefaults
    private let hasDevicePIN: () -> Bool
    private let onAuthenticated: () -> Void
    private let onSignedOut: () -> Void
    private var eventsTask: Task<Void, Never>?

    init(
        service: AccountService,
        defaults: UserDefaults = .standard,
        hasDevicePIN: @escaping () -> Bool,
        onAuthenticated: @escaping () -> Void,
        onSignedOut: @escaping () -> Void
    ) {
        self.service = service
        self.defaults = defaults
        self.hasDevicePIN = hasDevicePIN
        self.onAuthenticated = onAuthenticated
        self.onSignedOut = onSignedOut
    }

    var userName: String? {
        user?.name
    }

    var user: AccountUser? {
        guard case .signedIn(let user) = state else { return nil }
        return user
    }

    func refreshUser() async {
        guard user != nil, let fresh = try? await service.refreshUser() else { return }
        apply(fresh)
    }

    func updateAvatarVersion(_ version: Int?) async throws(AccountError) -> AccountUser {
        let updated = try await service.updateAvatarVersion(version)
        apply(updated)
        return updated
    }

    func apply(_ updated: AccountUser) {
        guard case .signedIn(let current) = state, current.id == updated.id else { return }
        state = .signedIn(updated)
    }

    func start() async {
        guard state == .loading else { return }

        if !defaults.bool(forKey: AccountConstants.installMarkerKey) {
            await service.signOut(scope: .local)
            defaults.removeObject(forKey: AccountConstants.legacyNameKey)
            defaults.set(true, forKey: AccountConstants.installMarkerKey)
            onSignedOut()
            state = .signedOut
        } else if let user = service.currentUser() {
            if hasDevicePIN() {
                state = .signedIn(user)
            } else {
                await service.signOut(scope: .local)
                onSignedOut()
                state = .signedOut
            }
        } else {
            state = .signedOut
        }

        listenToEvents()
    }

    func signUp(name: String, email: String, password: String) async {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = normalized(email)
        guard beginRequest(password: password) else { return }
        defer { isWorking = false }

        do {
            if let user = try await service.signUp(name: name, email: email, password: password) {
                authenticated(user)
            } else {
                state = .awaitingConfirmation(email: email)
            }
        } catch {
            errorMessage = error.message
        }
    }

    func signIn(email: String, password: String) async {
        guard beginRequest(password: password) else { return }
        defer { isWorking = false }

        do {
            authenticated(try await service.signIn(email: normalized(email), password: password))
        } catch {
            errorMessage = error.message
        }
    }

    func confirmAndSignIn(password: String) async {
        guard case .awaitingConfirmation(let email) = state else { return }
        await signIn(email: email, password: password)
    }

    func backToSignIn() {
        errorMessage = nil
        state = .signedOut
    }

    func sendPasswordReset(email: String) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await service.sendPasswordReset(email: normalized(email))
            return true
        } catch {
            errorMessage = error.message
            return false
        }
    }

    func handle(url: URL) async {
        switch state {
        case .signedOut, .awaitingConfirmation:
            break
        case .loading, .signedIn, .recoveringPassword:
            return
        }

        let isRecovery = url.path == AccountConstants.recoveryPath
        do {
            let user = try await service.handle(url: url)
            if isRecovery {
                errorMessage = nil
                state = .recoveringPassword(user)
            } else {
                authenticated(user)
            }
        } catch {
            if isRecovery {
                errorMessage = AccountError.invalidRecoveryLink.message
                state = .signedOut
            } else {
                errorMessage = AccountError.invalidConfirmationLink.message
            }
        }
    }

    func cancelPasswordRecovery() async {
        guard case .recoveringPassword = state else { return }
        errorMessage = nil
        state = .signedOut
        await service.signOut(scope: .local)
    }

    func saveNewPassword(_ password: String) async {
        guard case .recoveringPassword(let user) = state, beginRequest(password: password) else { return }
        defer { isWorking = false }

        do {
            try await service.updatePassword(password)
            await service.signOut(scope: .others)
            authenticated(user)
        } catch {
            errorMessage = error.message
        }
    }

    func signOut() async {
        state = .signedOut
        errorMessage = nil
        onSignedOut()
        await service.signOut(scope: .local)
    }

    private func beginRequest(password: String) -> Bool {
        guard !isWorking else { return false }
        guard password.count >= AccountConstants.minimumPasswordLength else {
            errorMessage = AccountError.weakPassword.message
            return false
        }
        isWorking = true
        errorMessage = nil
        return true
    }

    private func authenticated(_ user: AccountUser) {
        errorMessage = nil
        state = .signedIn(user)
        onAuthenticated()
    }

    private func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func listenToEvents() {
        let stream = service.events()
        eventsTask = Task { [weak self] in
            for await event in stream {
                self?.apply(event)
            }
        }
    }

    private func apply(_ event: AccountEvent) {
        switch (event, state) {
        case (.signedOut, .signedIn), (.signedOut, .recoveringPassword):
            onSignedOut()
            state = .signedOut
        case (.signedOut, _):
            break
        }
    }
}
