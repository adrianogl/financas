import AppIntents

struct SpendingEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Gasto do mês"
    static let defaultQuery = SpendingQuery()

    let id: UUID
    let name: String
    let monthTotal: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(monthTotal)")
    }
}
