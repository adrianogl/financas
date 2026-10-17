enum NonBusinessDayRule: String, Codable, Sendable, CaseIterable {
    case next
    case previous
    case keep

    var title: String {
        switch self {
        case .next: "Próximo dia útil"
        case .previous: "Dia útil anterior"
        case .keep: "Manter a data"
        }
    }

    var ruleSuffix: String? {
        switch self {
        case .next: "próximo dia útil"
        case .previous: "dia útil anterior"
        case .keep: nil
        }
    }

    func formHint(hourly: Bool) -> String {
        let base = switch self {
        case .next: "Se o dia não for útil, cai no próximo dia útil."
        case .previous: "Se o dia não for útil, cai no dia útil anterior."
        case .keep: "A data fica no dia escolhido, mesmo se não for útil."
        }
        return hourly ? "\(base) O pagamento cobre os dias úteis do mês anterior." : base
    }
}
