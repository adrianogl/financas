import SwiftUI

struct MonthPicker: View {
    @Binding var month: YearMonth

    var body: some View {
        HStack {
            Button("Mês anterior", systemImage: "chevron.left") {
                month = month.previous
            }
            Spacer()
            Text(IncomeFormat.monthTitle(month))
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            Button("Próximo mês", systemImage: "chevron.right") {
                month = month.next
            }
        }
        .labelStyle(.iconOnly)
        .font(.headline)
        .tint(Theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .animation(.smooth, value: month)
    }
}
