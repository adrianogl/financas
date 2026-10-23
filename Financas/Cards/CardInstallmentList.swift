import SwiftUI

struct CardInstallmentList: View {
    @Environment(CardStore.self) private var store
    let plans: [InstallmentPlan]

    var body: some View {
        CardListCard(items: plans, emptyText: "Nenhuma compra parcelada em andamento.") { plan in
            CardInstallmentRow(plan: plan, nickname: store.nickname(for: plan.cardAccountID), today: store.today)
        }
    }
}
