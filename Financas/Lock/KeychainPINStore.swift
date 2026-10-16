import CryptoKit
import Foundation
import Security

@MainActor
final class KeychainPINStore: PINStore {
    private let defaults: UserDefaults
    private let service: String

    init(defaults: UserDefaults = .standard, service: String = LockConstants.keychainService) {
        self.defaults = defaults
        self.service = service
    }

    var hasPIN: Bool {
        readRecord() != nil
    }

    var failedAttempts: Int {
        get { defaults.integer(forKey: LockConstants.failedAttemptsKey) }
        set { defaults.set(newValue, forKey: LockConstants.failedAttemptsKey) }
    }

    var lockedUntil: Date? {
        get { defaults.object(forKey: LockConstants.lockedUntilKey) as? Date }
        set { defaults.set(newValue, forKey: LockConstants.lockedUntilKey) }
    }

    func save(_ pin: String) throws(PINStoreError) {
        var salt = Data(count: LockConstants.saltLength)
        let randomStatus = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, LockConstants.saltLength, buffer.baseAddress!)
        }
        guard randomStatus == errSecSuccess else { throw .randomBytesUnavailable }

        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = salt + Self.digest(pin, salt: salt)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw .keychain(status) }
    }

    func matches(_ pin: String) -> Bool {
        guard let record = readRecord(), record.count > LockConstants.saltLength else { return false }
        let salt = Data(record.prefix(LockConstants.saltLength))
        let storedDigest = Data(record.dropFirst(LockConstants.saltLength))
        return Self.digest(pin, salt: salt) == storedDigest
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
        failedAttempts = 0
        lockedUntil = nil
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: LockConstants.keychainAccount,
        ]
    }

    private func readRecord() -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func digest(_ pin: String, salt: Data) -> Data {
        Data(SHA256.hash(data: salt + Data(pin.utf8)))
    }
}
