import SwiftUI

struct OverdueExpenseList: View {
    let payables: [ExpensePayable]
    let context: ListDetailContext
    let today: CalendarDay
    let pay: (ExpensePayable) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(payables.indices, id: \.self) { index in
                row(payables[index])
                if index < payables.count - 1 {
                    Divider()
                        .opacity(hidesDivider(after: index) ? 0 : 1)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ payable: ExpensePayable) -> some View {
        if payable.part == nil {
            let route = DetailRoute(payable.occurrence)
            DetailRowLink(route: route, context: context) {
                OverdueExpenseRow(payable: payable, today: today, isSelected: context.isSelected(route))
            }
        } else {
            Button {
                pay(payable)
            } label: {
                OverdueExpenseRow(payable: payable, today: today, isSelected: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func hidesDivider(after index: Int) -> Bool {
        [index, index + 1].contains { isSelected(payables[$0]) }
    }

    private func isSelected(_ payable: ExpensePayable) -> Bool {
        payable.part == nil && context.isSelected(DetailRoute(payable.occurrence))
    }
}
