import SwiftUI

struct QuickSpendingSheet: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @FocusState private var amountFocused: Bool
    @State private var draft: ExpenseEntryDraft?
    let today: CalendarDay
    let createSpending: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if options.isEmpty {
                    empty
                } else {
                    form
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Lançar gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                if draft != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Lançar", systemImage: "checkmark", action: save)
                            .disabled(store.isSaving)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .onAppear(perform: start)
    }

    private var options: [Expense] {
        store.spendings(in: today.yearMonth, today: today).map(\.expense)
    }

    private var form: some View {
        Form {
            if let draft {
                Section {
                    LabeledContent("Valor") {
                        TextField("Valor", value: amount, format: .currency(code: IncomeConstants.currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.accent)
                            .focused($amountFocused)
                    }
                    Picker("Em", selection: expenseID) {
                        ForEach(options) { expense in
                            Text(expense.name).tag(expense.id)
                        }
                    }
                    DatePicker("Data", selection: spentOn, in: dateRange(draft), displayedComponents: .date)
                }

                if let message = (draft.amount == nil ? nil : draft.validationMessage) ?? store.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    GlassPrimaryButton(title: "Lançar", isWorking: store.isSaving, action: save)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Para lançar padaria, mercado ou farmácia, crie antes um gasto do mês, como \"Mercado\" ou \"Avulsos\". O valor previsto é opcional.")
                .foregroundStyle(.secondary)
            Spacer()
            GlassPrimaryButton(title: "Criar gasto do mês") {
                dismiss()
                createSpending()
            }
        }
        .padding(24)
    }

    private var amount: Binding<Decimal?> {
        Binding(get: { draft?.amount }, set: { draft?.amount = $0 })
    }

    private var expenseID: Binding<UUID> {
        Binding(
            get: { draft?.expense.id ?? UUID() },
            set: { id in
                guard let expense = options.first(where: { $0.id == id }), let current = draft else { return }
                var next = ExpenseEntryDraft(expense: expense, month: today.yearMonth, today: today)
                next.amount = current.amount
                next.spentOn = current.spentOn
                draft = next
            }
        )
    }

    private var spentOn: Binding<Date> {
        Binding(
            get: { draft?.spentOn.date() ?? today.date() },
            set: { draft?.spentOn = CalendarDay(date: $0) }
        )
    }

    private func dateRange(_ draft: ExpenseEntryDraft) -> ClosedRange<Date> {
        draft.validRange.lowerBound.date()...draft.validRange.upperBound.date()
    }

    private func start() {
        guard draft == nil,
              let expense = QuickSpending.defaultExpense(options: options, entries: store.snapshot.entries) else { return }
        draft = ExpenseEntryDraft(expense: expense, month: today.yearMonth, today: today)
        amountFocused = true
    }

    private func save() {
        guard let draft else { return }
        Task {
            if await store.saveEntry(draft) { dismiss() }
        }
    }
}
