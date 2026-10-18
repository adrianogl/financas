import SwiftUI

struct ExpenseFormView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ExpenseDraft
    private let initialDraft: ExpenseDraft
    @State private var endsExpense = false
    @State private var endMonth: YearMonth
    @State private var confirmsDelete = false

    private let expense: Expense?

    init(draft: ExpenseDraft, expense: Expense?, today: CalendarDay) {
        _draft = State(initialValue: draft)
        initialDraft = draft
        _endMonth = State(initialValue: max(today.yearMonth, draft.startMonth))
        self.expense = expense
    }

    var body: some View {
        NavigationStack {
            Form {
                if draft.isNew {
                    Section {
                        Picker("Tipo", selection: $draft.kind) {
                            Text(ExpenseConstants.billKindTitle).tag(ExpenseKind.bill)
                            Text(ExpenseConstants.spendingKindTitle).tag(ExpenseKind.spending)
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                switch draft.kind {
                case .bill:
                    billFields
                case .spending:
                    spendingFields
                }

                Section {
                    MonthField(title: "Início", month: $draft.startMonth)
                        .disabled(!draft.isNew)
                    Toggle("Tem mês de fim", isOn: hasEnd)
                    if let end = draft.endMonth {
                        MonthField(title: "Fim", month: Binding(get: { end }, set: { draft.endMonth = $0 }))
                    }
                } footer: {
                    if draft.kind == .spending {
                        Text(ExpenseConstants.spendingFooter)
                    }
                }

                if let message = (draft == initialDraft ? nil : draft.validationMessage) ?? store.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    .listRowBackground(Color.clear)
                }

                if let expense {
                    manageSection(expense)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(draft.isNew ? "Nova despesa" : "Editar despesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", systemImage: "checkmark") {
                        Task {
                            if await store.save(draft, today: incomeStore.today) { dismiss() }
                        }
                    }
                    .disabled(draft.validationMessage != nil || store.isSaving)
                }
            }
            .confirmationDialog("Excluir despesa?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Excluir", role: .destructive) {
                    guard let expense else { return }
                    Task {
                        if await store.delete(expense) { dismiss() }
                    }
                }
            } message: {
                Text("As contas lançadas e os pagamentos desta despesa também serão apagados.")
            }
        }
    }

    @ViewBuilder
    private var billFields: some View {
        Section {
            TextField("Nome", text: $draft.name)
                .textInputAutocapitalization(.sentences)
            if draft.parts.isEmpty {
                amountFields
            }
        }

        ExpensePartsSection(draft: $draft)

        Section {
            Picker("Dia de vencimento", selection: $draft.dayOfMonth) {
                ForEach(IncomeFormConstants.days, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
        }
    }

    @ViewBuilder
    private var spendingFields: some View {
        Section {
            TextField("Nome", text: $draft.name)
                .textInputAutocapitalization(.sentences)
            TextField("Previsto por mês", value: $draft.estimatedAmount, format: .currency(code: IncomeConstants.currencyCode))
                .keyboardType(.decimalPad)
        }
    }

    @ViewBuilder
    private var amountFields: some View {
        Picker("Valor", selection: $draft.isFixed) {
            Text("Fixo").tag(true)
            Text("Varia").tag(false)
        }
        .pickerStyle(.segmented)
        TextField(draft.isFixed ? "Valor" : "Valor estimado", value: $draft.estimatedAmount, format: .currency(code: IncomeConstants.currencyCode))
            .keyboardType(.decimalPad)
    }

    private func manageSection(_ expense: Expense) -> some View {
        Section {
            if expense.endMonth == nil {
                if endsExpense {
                    MonthField(title: "Último mês", month: $endMonth)
                    Button("Confirmar encerramento") {
                        Task {
                            if await store.end(expense, in: endMonth) { dismiss() }
                        }
                    }
                    .disabled(store.isSaving)
                } else {
                    Button("Encerrar despesa") {
                        endsExpense = true
                    }
                }
            }
            Button("Excluir despesa", role: .destructive) {
                confirmsDelete = true
            }
        }
    }

    private var hasEnd: Binding<Bool> {
        Binding(
            get: { draft.endMonth != nil },
            set: { draft.endMonth = $0 ? max(draft.startMonth, incomeStore.today.yearMonth) : nil }
        )
    }
}
