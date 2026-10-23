import SwiftUI

struct CardFixedChargesView: View {
    @Environment(CardStore.self) private var store
    @State private var ending: FixedCharge?

    var body: some View {
        let charges = store.fixedCharges.sorted { $0.amount > $1.amount }

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let message = store.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 6)
                }
                CardListCard(items: charges, emptyText: "Nenhum fixo confirmado.") { charge in
                    HStack(spacing: 12) {
                        CardFixedRow(charge: charge, nickname: store.nickname(for: charge.recurrence.cardAccountID))
                        Button("Encerrar", role: .destructive) {
                            ending = charge
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.glass)
                        .controlSize(.small)
                    }
                }
            }
            .padding(20)
            .readableWidth(LayoutConstants.contentWidth)
        }
        .background(AppBackground())
        .navigationTitle("Fixos")
        .confirmationDialog(
            ending.map { "Encerrar \($0.name)?" } ?? "",
            isPresented: Binding(get: { ending != nil }, set: { if !$0 { ending = nil } }),
            titleVisibility: .visible,
            presenting: ending
        ) { charge in
            Button("Encerrar", role: .destructive) {
                Task { await store.end(charge) }
            }
        } message: { _ in
            Text("O fixo deixa de contar no comprometido. Se voltar a ser cobrado, ele aparece para revisar.")
        }
    }
}
