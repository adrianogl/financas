import Foundation

enum HomeStatText {
    static func expected(_ amount: Decimal) -> String {
        "de \(IncomeFormat.currency(amount))"
    }

    static func overdueBadge(_ count: Int) -> String? {
        switch count {
        case 0:
            nil
        case 1:
            "1 atrasada"
        default:
            "\(count) atrasadas"
        }
    }

    static func overdueNames(_ names: [String]) -> String {
        var seen = Set<String>()
        let shown = names.filter { seen.insert($0).inserted }.prefix(HomeConstants.overdueNameLimit)
        return shown.isEmpty ? "Nada atrasado" : shown.joined(separator: " · ")
    }

    static func balanceCaption(_ month: YearMonth) -> String {
        "recebido menos pago em \(IncomeFormat.monthName(month))"
    }
}
