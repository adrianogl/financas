import Foundation

extension CardStore {
    func nickname(for accountID: UUID) -> String {
        snapshot.accounts.first { $0.id == accountID }?.nickname ?? ""
    }

    func nickname(for connection: CardConnection) -> String {
        let names = accounts.filter { $0.connectionID == connection.id }.map(\.nickname)
        guard let last = names.last else { return "Conexão" }
        return names.count == 1 ? last : "\(names.dropLast().joined(separator: ", ")) e \(last)"
    }
}
