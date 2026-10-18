import SwiftUI

struct ExpenseBillPartsSection: View {
    @Binding var draft: ExpenseBillDraft

    var body: some View {
        Section {
            ForEach($draft.parts) { $part in
                LabeledContent(part.name) {
                    TextField(part.name, value: $part.amount, format: .currency(code: IncomeConstants.currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.accent)
                }
            }
            LabeledContent("Total") {
                Text(IncomeFormat.currency(draft.partsTotal))
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
        }
    }
}
