import SwiftUI

extension IncomeKind {
    var systemImage: String {
        switch self {
        case .fixed: "arrow.down"
        case .hourly: "clock"
        case .oneOff: "gift"
        }
    }

    var tint: Color {
        switch self {
        case .fixed: Theme.categoryTints[2]
        case .hourly: Theme.categoryTints[0]
        case .oneOff: Theme.categoryTints[1]
        }
    }

    var title: String {
        switch self {
        case .fixed: "Fixa"
        case .hourly: "Por hora"
        case .oneOff: "Avulsa"
        }
    }
}
