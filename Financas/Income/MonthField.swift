import SwiftUI

struct MonthField: View {
    let title: String
    @Binding var month: YearMonth

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button("Mês anterior", systemImage: "chevron.left") {
                month = month.previous
            }
            Text(IncomeFormat.monthTitle(month))
                .monospacedDigit()
                .frame(minWidth: 130)
            Button("Próximo mês", systemImage: "chevron.right") {
                month = month.next
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .tint(Theme.accent)
    }
}
