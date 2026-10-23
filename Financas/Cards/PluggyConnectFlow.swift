import Foundation
import Observation

@MainActor
@Observable
final class PluggyConnectFlow {
    var request: PluggyConnectRequest?
    private(set) var failure: String?
    private(set) var isWorking = false

    func begin(for connection: CardConnection?, store: CardStore) async {
        failure = nil
        isWorking = true
        defer { isWorking = false }
        guard let token = await store.connectToken(for: connection) else { return }
        request = PluggyConnectRequest(token: token, itemID: connection?.itemID)
    }

    func handle(_ event: PluggyConnectEvent, store: CardStore) async -> Bool {
        switch event {
        case .success(let itemID):
            failure = nil
            return await store.register(itemID: itemID)
        case .error:
            failure = CardConstants.connectFailedMessage
            return false
        case .close:
            return false
        }
    }
}
