import LocalAuthentication

@MainActor
struct BiometricAuthenticator: Authenticator {
    var availableBiometry: BiometryKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return .none }
        switch context.biometryType {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        default: return .none
        }
    }

    func authenticate(reason: String, allowsDevicePasscode: Bool) async throws(AuthenticationError) {
        let context = LAContext()
        let policy: LAPolicy = allowsDevicePasscode ? .deviceOwnerAuthentication : .deviceOwnerAuthenticationWithBiometrics
        if !allowsDevicePasscode {
            context.localizedFallbackTitle = LockConstants.fallbackTitle
        }

        var availabilityError: NSError?
        guard context.canEvaluatePolicy(policy, error: &availabilityError) else {
            throw .unavailable
        }

        let clock = ContinuousClock()
        let start = clock.now
        let timeout = Task { @MainActor in
            try await Task.sleep(for: LockConstants.biometricTimeout)
            context.invalidate()
        }
        defer { timeout.cancel() }

        do {
            _ = try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch let error as LAError where error.code == .appCancel && clock.now - start >= LockConstants.biometricTimeout {
            throw .timedOut
        } catch let error as LAError where error.code == .userFallback {
            throw .fallback
        } catch let error as LAError where LockConstants.cancellationCodes.contains(error.code) {
            throw .cancelled
        } catch let error as LAError where LockConstants.unavailableCodes.contains(error.code) {
            throw .unavailable
        } catch {
            throw .failed
        }
    }
}
