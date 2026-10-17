import SwiftUI

struct OverdueTotalCard: View {
    let total: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total atrasado")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(total))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.warning)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}
