import SwiftUI

struct OverdueTotalCard: View {
    let incoming: Decimal
    let outgoing: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if incoming > 0 {
                line("A receber", amount: incoming)
            }
            if outgoing > 0 {
                line("A pagar", amount: outgoing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func line(_ title: String, amount: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(amount))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.warning)
        }
    }
}
