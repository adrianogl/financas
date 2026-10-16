@MainActor
protocol Authenticator {
    var availableBiometry: BiometryKind { get }

    func authenticate(reason: String, allowsDevicePasscode: Bool) async throws(AuthenticationError)
}
