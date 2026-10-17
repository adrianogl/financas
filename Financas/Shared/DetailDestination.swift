import SwiftUI

struct DetailDestination: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: DetailRoute.self) { route in
            Group {
                switch route {
                case .income(let id, let month):
                    IncomeDetailView(occurrenceID: id, month: month)
                case .expense(let id, let month):
                    ExpenseDetailView(occurrenceID: id, month: month)
                }
            }
            .background(AppBackground())
        }
    }
}

extension View {
    func detailDestination() -> some View {
        modifier(DetailDestination())
    }
}
