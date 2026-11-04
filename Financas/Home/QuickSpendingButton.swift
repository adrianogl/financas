import SwiftUI

struct QuickSpendingButton: View {
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(AppNavigation.self) private var navigation
    @State private var isPresented = false

    var body: some View {
        Button("Lançar gasto", systemImage: "plus") {
            isPresented = true
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .sheet(isPresented: $isPresented) {
            QuickSpendingSheet(today: incomeStore.today) {
                navigation.section = .expenses
            }
        }
    }
}
