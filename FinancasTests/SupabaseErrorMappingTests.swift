import Foundation
import Supabase
import Testing
@testable import Financas

@MainActor
struct SupabaseErrorMappingTests {
    private func apiError(_ code: ErrorCode) -> AuthError {
        .api(message: "", errorCode: code, underlyingData: Data(), underlyingResponse: HTTPURLResponse())
    }

    @Test func emailRateLimitHasOwnMessage() {
        #expect(SupabaseAccountService.accountError(from: apiError(.overEmailSendRateLimit)) == .emailRateLimited)
    }

    @Test func samePasswordHasOwnMessage() {
        #expect(SupabaseAccountService.accountError(from: apiError(.samePassword)) == .samePassword)
    }

    @Test func missingRecoverySessionMeansInvalidLink() {
        #expect(SupabaseAccountService.accountError(from: AuthError.sessionMissing) == .invalidRecoveryLink)
        #expect(SupabaseAccountService.accountError(from: apiError(.sessionNotFound)) == .invalidRecoveryLink)
    }

    @Test func offlineIsNetworkError() {
        #expect(SupabaseAccountService.accountError(from: URLError(.notConnectedToInternet)) == .network)
    }
}
