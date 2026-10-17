import Foundation
import Testing
@testable import Financas

@MainActor
final class AccountManagerHarness {
    let service = FakeAccountService()
    let defaults = UserDefaults(suiteName: "AccountManagerTests.\(UUID().uuidString)")!
    var hasPIN = true
    var authenticatedCount = 0
    var signedOutCount = 0
    lazy var manager = AccountManager(
        service: service,
        defaults: defaults,
        hasDevicePIN: { [unowned self] in hasPIN },
        onAuthenticated: { [unowned self] in authenticatedCount += 1 },
        onSignedOut: { [unowned self] in signedOutCount += 1 }
    )

    init(installed: Bool = true) {
        if installed {
            defaults.set(true, forKey: AccountConstants.installMarkerKey)
        }
    }

    func settle() async {
        for _ in 0..<10 { await Task.yield() }
    }
}

@MainActor
struct AccountManagerTests {
    @Test func freshInstallDiscardsSessionAndLegacyName() async {
        let harness = AccountManagerHarness(installed: false)
        harness.defaults.set("X", forKey: AccountConstants.legacyNameKey)
        harness.service.storedUser = .sample

        await harness.manager.start()

        #expect(harness.service.signOutScopes == [.local])
        #expect(harness.signedOutCount == 1)
        #expect(harness.manager.state == .signedOut)
        #expect(harness.defaults.string(forKey: AccountConstants.legacyNameKey) == nil)
        #expect(harness.defaults.bool(forKey: AccountConstants.installMarkerKey))
    }

    @Test func restoresSignedInUser() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample

        await harness.manager.start()

        #expect(harness.manager.state == .signedIn(.sample))
        #expect(harness.manager.userName == "Adriano")
        #expect(harness.signedOutCount == 0)
    }

    @Test func restoredSessionWithoutPINIsDiscarded() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        harness.hasPIN = false

        await harness.manager.start()

        #expect(harness.manager.state == .signedOut)
        #expect(harness.service.signOutScopes == [.local])
    }

    @Test func staysSignedInWhenServiceHasNoEvents() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample

        await harness.manager.start()
        await harness.settle()

        #expect(harness.manager.state == .signedIn(.sample))
    }

    @Test func serverSignOutEventSignsOut() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        await harness.manager.start()

        harness.service.send(.signedOut)
        await harness.settle()

        #expect(harness.manager.state == .signedOut)
        #expect(harness.signedOutCount == 1)
    }

    @Test func signInSucceeds() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()

        await harness.manager.signIn(email: "eu@mail.com", password: "senha1234")

        #expect(harness.manager.state == .signedIn(.sample))
        #expect(harness.authenticatedCount == 1)
    }

    @Test func normalizesEmail() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()

        await harness.manager.signIn(email: "  Eu@Mail.COM ", password: "senha1234")

        #expect(harness.service.signInCalls.first?.email == "eu@mail.com")
    }

    @Test func shortPasswordIsRejectedLocally() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()

        await harness.manager.signIn(email: "eu@mail.com", password: "1234567")

        #expect(harness.manager.errorMessage == AccountError.weakPassword.message)
        #expect(harness.service.signInCalls.isEmpty)
    }

    @Test func wrongPasswordShowsMessage() async {
        let harness = AccountManagerHarness()
        harness.service.signInResult = .failure(.invalidCredentials)
        await harness.manager.start()

        await harness.manager.signIn(email: "eu@mail.com", password: "senha1234")

        #expect(harness.manager.errorMessage == "E-mail ou senha incorretos.")
        #expect(harness.manager.state == .signedOut)
    }

    @Test func networkErrorOnSignInKeepsState() async {
        let harness = AccountManagerHarness()
        harness.service.signInResult = .failure(.network)
        await harness.manager.start()

        await harness.manager.signIn(email: "eu@mail.com", password: "senha1234")

        #expect(harness.manager.state == .signedOut)
        #expect(harness.manager.errorMessage == "Sem conexão. Verifique a internet e tente de novo.")
    }

    @Test func ignoresSecondRequestWhileWorking() async {
        let harness = AccountManagerHarness()
        harness.service.suspendsSignIn = true
        await harness.manager.start()

        async let first: Void = harness.manager.signIn(email: "eu@mail.com", password: "senha1234")
        await harness.settle()
        await harness.manager.signIn(email: "eu@mail.com", password: "senha1234")
        harness.service.releaseSignIn()
        await first

        #expect(harness.service.signInCalls.count == 1)
    }

    @Test func signUpNeedingConfirmationWaits() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()

        await harness.manager.signUp(name: " Adriano ", email: "Eu@mail.com", password: "senha1234")

        #expect(harness.manager.state == .awaitingConfirmation(email: "eu@mail.com"))
        #expect(harness.service.signUpCalls.first?.name == "Adriano")
    }

    @Test func confirmWithWrongPasswordStaysAwaiting() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()
        await harness.manager.signUp(name: "Adriano", email: "eu@mail.com", password: "senha1234")
        harness.service.signInResult = .failure(.invalidCredentials)

        await harness.manager.confirmAndSignIn(password: "outrasenha")

        #expect(harness.manager.state == .awaitingConfirmation(email: "eu@mail.com"))
        #expect(harness.manager.errorMessage == "E-mail ou senha incorretos.")
    }

    @Test func recoveryLinkOpensNewPassword() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()

        await harness.manager.handle(url: AccountConstants.recoveryRedirectURL)

        #expect(harness.manager.state == .recoveringPassword(.sample))
    }

    @Test func invalidRecoveryLinkShowsMessage() async {
        let harness = AccountManagerHarness()
        harness.service.handleResult = .failure(.unknown)
        await harness.manager.start()

        await harness.manager.handle(url: AccountConstants.recoveryRedirectURL)

        #expect(harness.manager.state == .signedOut)
        #expect(harness.manager.errorMessage == "O link expirou ou foi aberto em outro aparelho. Peça um novo neste aparelho.")
    }

    @Test func confirmationLinkSignsIn() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()
        await harness.manager.signUp(name: "Adriano", email: "eu@mail.com", password: "senha1234")

        await harness.manager.handle(url: AccountConstants.redirectURL)

        #expect(harness.manager.state == .signedIn(.sample))
        #expect(harness.authenticatedCount == 1)
    }

    @Test func invalidConfirmationLinkKeepsConfirmationScreen() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()
        await harness.manager.signUp(name: "Adriano", email: "eu@mail.com", password: "senha1234")
        harness.service.handleResult = .failure(.unknown)

        await harness.manager.handle(url: AccountConstants.redirectURL)

        #expect(harness.manager.state == .awaitingConfirmation(email: "eu@mail.com"))
        #expect(harness.manager.errorMessage == AccountError.invalidConfirmationLink.message)
    }

    @Test func linkIsIgnoredWhileSignedIn() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        await harness.manager.start()

        await harness.manager.handle(url: AccountConstants.recoveryRedirectURL)

        #expect(harness.manager.state == .signedIn(.sample))
        #expect(harness.service.handledURLs.isEmpty)
        #expect(harness.signedOutCount == 0)
    }

    @Test func cancelPasswordRecoverySignsOutLocally() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()
        await harness.manager.handle(url: AccountConstants.recoveryRedirectURL)

        await harness.manager.cancelPasswordRecovery()

        #expect(harness.manager.state == .signedOut)
        #expect(harness.service.signOutScopes == [.local])
    }

    @Test func newPasswordSignsOutOtherDevices() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()
        await harness.manager.handle(url: AccountConstants.recoveryRedirectURL)

        await harness.manager.saveNewPassword("novasenha1")

        #expect(harness.service.updatedPasswords == ["novasenha1"])
        #expect(harness.service.signOutScopes == [.others])
        #expect(harness.manager.state == .signedIn(.sample))
        #expect(harness.authenticatedCount == 1)
    }

    @Test func signOutClearsEverything() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        await harness.manager.start()

        await harness.manager.signOut()

        #expect(harness.service.signOutScopes == [.local])
        #expect(harness.signedOutCount == 1)
        #expect(harness.manager.state == .signedOut)
    }

    @Test func refreshUserUpdatesNameAndAvatar() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        await harness.manager.start()
        var fresh = AccountUser.sample
        fresh = AccountUser(id: fresh.id, email: fresh.email, name: "Novo", avatarVersion: 7)
        harness.service.refreshResult = .success(fresh)

        await harness.manager.refreshUser()

        #expect(harness.manager.state == .signedIn(fresh))
        #expect(harness.manager.user?.avatarVersion == 7)
    }

    @Test func refreshUserNetworkErrorKeepsUser() async {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        await harness.manager.start()
        harness.service.refreshResult = .failure(.network)

        await harness.manager.refreshUser()

        #expect(harness.manager.state == .signedIn(.sample))
        #expect(harness.signedOutCount == 0)
    }

    @Test func refreshUserIgnoredWhenSignedOut() async {
        let harness = AccountManagerHarness()
        await harness.manager.start()
        harness.service.refreshResult = .success(.sample)

        await harness.manager.refreshUser()

        #expect(harness.manager.state == .signedOut)
    }

    @Test func updateAvatarVersionAppliesUser() async throws {
        let harness = AccountManagerHarness()
        harness.service.storedUser = .sample
        await harness.manager.start()

        let user = try await harness.manager.updateAvatarVersion(42)

        #expect(user.avatarVersion == 42)
        #expect(harness.manager.user?.avatarVersion == 42)
        #expect(harness.service.updatedAvatarVersions == [42])
    }
}
