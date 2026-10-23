import Foundation

enum PluggyConnectEvent: Equatable {
    case success(itemID: String)
    case error
    case close

    var dismissesSheet: Bool {
        switch self {
        case .success, .close: true
        case .error: false
        }
    }

    static func parse(_ body: Any) -> PluggyConnectEvent? {
        guard let payload = body as? [String: Any], let event = payload["event"] as? String else { return nil }
        switch event {
        case "success":
            guard let itemID = payload["itemId"] as? String, !itemID.isEmpty else { return .error }
            return .success(itemID: itemID)
        case "error":
            return .error
        case "close":
            return .close
        default:
            return nil
        }
    }
}
