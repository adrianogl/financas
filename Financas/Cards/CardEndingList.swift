import SwiftUI

struct CardEndingList: View {
    @Environment(CardStore.self) private var store
    let plans: [InstallmentPlan]

    var body: some View {
        CardListCard(items: plans, emptyText: "Nenhuma parcela termina nos próximos 3 meses.") { plan in
            CardEndingRow(plan: plan, nickname: store.nickname(for: plan.cardAccountID))
        }
    }
}
