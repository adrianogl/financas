import SwiftUI

struct DetailRouteView: View {
    let route: DetailRoute

    var body: some View {
        switch route {
        case .income(let id, let month):
            IncomeDetailView(occurrenceID: id, month: month)
        case .expense(let id, let month):
            ExpenseDetailView(occurrenceID: id, month: month)
        case .spending(let id, let month):
            SpendingDetailView(spendingID: id, month: month)
        }
    }
}
