import SwiftUI

struct CardInstallmentsView: View {
    @Environment(CardStore.self) private var store

    var body: some View {
        let plans = store.plans.sorted { ($0.lastMonth, $0.name) < ($1.lastMonth, $1.name) }

        ScrollView {
            CardInstallmentList(plans: plans)
                .padding(20)
                .readableWidth(LayoutConstants.contentWidth)
        }
        .background(AppBackground())
        .navigationTitle("Parcelas")
    }
}
