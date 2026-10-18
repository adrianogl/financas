import SwiftUI

struct ExpenseSheet: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ExpenseBillDraft

    let occurrence: ExpenseOccurrence
    let editExpense: (Expense) -> Void

    init(target: ExpenseSheetTarget, today: CalendarDay, editExpense: @escaping (Expense) -> Void) {
        occurrence = target.occurrence
        self.editExpense = editExpense
        _draft = State(initialValue: ExpenseBillDraft(occurrence: target.occurrence, today: today, mode: target.mode))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)

                Picker("Modo", selection: $draft.mode) {
                    Text("Lançar conta").tag(ExpenseSheetMode.bill)
                    Text("Marcar como paga").tag(ExpenseSheetMode.payment)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                switch draft.mode {
                case .bill:
                    billFields
                case .payment:
                    paymentFields
                }

                if let message = store.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    GlassPrimaryButton(title: primaryTitle, isWorking: store.isSaving, action: save)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    switch draft.mode {
                    case .bill where occurrence.hasBill:
                        Button("Remover conta", role: .destructive) {
                            run { await store.removeBill(draft, for: occurrence) }
                        }
                    case .payment where occurrence.status == .paid:
                        Button("Desmarcar pagamento", role: .destructive) {
                            run { await store.unmarkPaid(draft, for: occurrence) }
                        }
                    default:
                        EmptyView()
                    }
                    Button("Editar despesa") {
                        dismiss()
                        editExpense(occurrence.expense)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("\(occurrence.expense.name) · \(IncomeFormat.monthName(occurrence.month))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", systemImage: "checkmark", action: save)
                        .disabled(store.isSaving)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Vence \(IncomeFormat.shortDate(occurrence.dueDate))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(occurrence.amount))
                .font(.system(size: 32, weight: .semibold))
                .monospacedDigit()
            Text(ExpenseFormat.origin(occurrence))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var billFields: some View {
        if hasParts {
            ExpenseBillPartsSection(draft: $draft)
        }
        Section {
            if !hasParts {
                LabeledContent("Valor da conta") {
                    TextField("Valor da conta", value: $draft.billAmount, format: .currency(code: IncomeConstants.currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.accent)
                }
            }
            DatePicker("Vencimento", selection: billDueDate, displayedComponents: .date)
        }
    }

    @ViewBuilder
    private var paymentFields: some View {
        if hasParts {
            ExpenseBillPartsSection(draft: $draft)
        }
        Section {
            if !hasParts {
                LabeledContent("Valor pago") {
                    TextField("Valor pago", value: $draft.paidAmount, format: .currency(code: IncomeConstants.currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.accent)
                }
            }
            DatePicker("Data do pagamento", selection: paidOn, in: ...incomeStore.today.date(), displayedComponents: .date)
        }
    }

    private var hasParts: Bool {
        !draft.parts.isEmpty
    }

    private var primaryTitle: String {
        switch draft.mode {
        case .bill: "Salvar conta"
        case .payment: "Marcar como paga"
        }
    }

    private func save() {
        switch draft.mode {
        case .bill:
            run { await store.saveBill(draft, for: occurrence) }
        case .payment:
            run { await store.markPaid(draft, for: occurrence) }
        }
    }

    private func run(_ operation: @escaping () async -> Bool) {
        Task {
            if await operation() { dismiss() }
        }
    }

    private var billDueDate: Binding<Date> {
        Binding(get: { draft.billDueDate.date() }, set: { draft.billDueDate = CalendarDay(date: $0) })
    }

    private var paidOn: Binding<Date> {
        Binding(get: { draft.paidOn.date() }, set: { draft.paidOn = CalendarDay(date: $0) })
    }
}
