import SwiftUI

enum MonthComparisonSeries {
    case income
    case expense

    var title: String {
        switch self {
        case .income: "Receitas"
        case .expense: "Despesas"
        }
    }

    var color: Color {
        switch self {
        case .income: Theme.accent
        case .expense: Theme.categoryTints[2]
        }
    }
}
