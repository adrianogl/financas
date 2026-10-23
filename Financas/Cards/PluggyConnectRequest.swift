import Foundation

struct PluggyConnectRequest: Identifiable {
    let id = UUID()
    let token: String
    let itemID: String?
}
