import Foundation

@MainActor
protocol PINStore: AnyObject {
    var hasPIN: Bool { get }
    var failedAttempts: Int { get set }
    var lockedUntil: Date? { get set }

    func save(_ pin: String) throws(PINStoreError)
    func matches(_ pin: String) -> Bool
    func clear()
}
