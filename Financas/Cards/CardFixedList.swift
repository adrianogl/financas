import SwiftUI

struct CardFixedList: View {
    @Environment(CardStore.self) private var store
    let charges: [FixedCharge]

    var body: some View {
        CardListCard(items: charges, emptyText: "Nenhum fixo confirmado.") { charge in
            CardFixedRow(charge: charge, nickname: store.nickname(for: charge.recurrence.cardAccountID))
        }
    }
}
