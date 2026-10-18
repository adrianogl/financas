import SwiftUI

struct ExpensePartsSection: View {
    @Binding var draft: ExpenseDraft

    var body: some View {
        Section {
            ForEach($draft.parts) { $part in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Remover parte", systemImage: "minus.circle.fill", role: .destructive) {
                            draft.removePart(id: part.id)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        TextField("Nome da parte", text: $part.name)
                            .textInputAutocapitalization(.sentences)
                        Picker("Tipo", selection: $part.isFixed) {
                            Text("Fixo").tag(true)
                            Text("Varia").tag(false)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        TextField("Valor", value: $part.amount, format: .currency(code: IncomeConstants.currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 80, maxWidth: 110)
                    }
                    Picker("Vence dia", selection: $part.dayOfMonth) {
                        Text(ExpenseConstants.partSameDayTitle).tag(Int?.none)
                        ForEach(IncomeFormConstants.days, id: \.self) { day in
                            Text("\(day)").tag(Int?.some(day))
                        }
                    }
                }
                .swipeActions {
                    Button("Apagar", role: .destructive) {
                        draft.removePart(id: part.id)
                    }
                }
            }
            Button("Adicionar parte", systemImage: "plus.circle.fill") {
                draft.addPart()
            }
        } header: {
            Text("Partes")
        } footer: {
            Text(ExpenseConstants.partsFooter)
        }
    }
}
