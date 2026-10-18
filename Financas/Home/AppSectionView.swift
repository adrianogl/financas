import SwiftUI

struct AppSectionView: View {
    let section: AppTab

    var body: some View {
        switch section {
        case .home:
            HomeView()
        case .incomes:
            IncomesView()
        case .expenses:
            ExpensesView()
        case .overdue:
            OverdueView()
        }
    }
}
