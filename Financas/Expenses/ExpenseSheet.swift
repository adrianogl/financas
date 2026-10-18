import SwiftUI

struct ExpenseSheet: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(IncomeStore.self) private var incomeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ExpenseBillDraft
    @State private var partDraft: ExpensePartBillDraft?

    let occurrence: ExpenseOccurrence
    let payable: ExpensePayable?
    let editExpense: (Expense) -> Void

    init(target: ExpenseSheetTarget, today: CalendarDay, editExpense: @escaping (Expense) -> Void) {
        occurrence = target.occurrence
        let part = target.partID.flatMap { id in target.occurrence.parts.first { $0.part.id == id } }
        payable = part.map { ExpensePayable(occurrence: target.occurrence, part: $0, today: today) }
        self.editExpense = editExpense
        _draft = State(initialValue: ExpenseBillDraft(occurrence: target.occurrence, today: today, mode: target.mode))
        _partDraft = State(initialValue: part.map { ExpensePartBillDraft(value: $0, today: today, mode: target.mode) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)

                Picker("Modo", selection: field(\.mode, \.mode)) {
                    Text("Lançar conta").tag(ExpenseSheetMode.bill)
                    Text("Marcar como paga").tag(ExpenseSheetMode.payment)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                switch mode {
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
                    switch mode {
                    case .bill where hasBill:
                        Button("Remover conta", role: .destructive, action: removeBill)
                    case .payment where isPaid:
                        Button("Desmarcar pagamento", role: .destructive, action: unmarkPaid)
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
            .navigationTitle(title)
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
            Text("Vence \(IncomeFormat.shortDate(payable?.dueDate ?? occurrence.dueDate))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(payable?.amount ?? occurrence.amount))
                .font(.system(size: 32, weight: .semibold))
                .monospacedDigit()
            Text(payable?.part.map { ExpenseFormat.origin($0) } ?? ExpenseFormat.origin(occurrence))
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
                    TextField("Valor da conta", value: field(\.billAmount, \.billAmount), format: .currency(code: IncomeConstants.currencyCode))
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
                    TextField("Valor pago", value: field(\.paidAmount, \.paidAmount), format: .currency(code: IncomeConstants.currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Theme.accent)
                }
            }
            DatePicker("Data do pagamento", selection: paidOn, in: ...incomeStore.today.date(), displayedComponents: .date)
        }
    }

    private var hasParts: Bool {
        payable == nil && !occurrence.parts.isEmpty
    }

    private var mode: ExpenseSheetMode {
        partDraft?.mode ?? draft.mode
    }

    private var hasBill: Bool {
        guard let payable else { return occurrence.hasBill }
        return payable.part?.bill?.billAmount != nil
    }

    private var isPaid: Bool {
        (payable?.status ?? occurrence.status) == .paid
    }

    private var title: String {
        let month = IncomeFormat.monthName(occurrence.month)
        guard let name = payable?.part?.part.name else { return "\(occurrence.expense.name) · \(month)" }
        return "\(occurrence.expense.name) · \(name) · \(month)"
    }

    private var primaryTitle: String {
        switch mode {
        case .bill: "Salvar conta"
        case .payment: "Marcar como paga"
        }
    }

    private func save() {
        if let partDraft, let payable {
            run { await store.savePartBill(partDraft, for: payable) }
            return
        }
        switch draft.mode {
        case .bill:
            run { await store.saveBill(draft, for: occurrence) }
        case .payment:
            run { await store.markPaid(draft, for: occurrence) }
        }
    }

    private func removeBill() {
        if let partDraft, let payable {
            run { await store.removePartBill(partDraft, for: payable) }
        } else {
            run { await store.removeBill(draft, for: occurrence) }
        }
    }

    private func unmarkPaid() {
        if let partDraft, let payable {
            run { await store.unmarkPartPaid(partDraft, for: payable) }
        } else {
            run { await store.unmarkPaid(draft, for: occurrence) }
        }
    }

    private func field<Value>(
        _ part: WritableKeyPath<ExpensePartBillDraft, Value>,
        _ whole: WritableKeyPath<ExpenseBillDraft, Value>
    ) -> Binding<Value> {
        Binding(
            get: { partDraft?[keyPath: part] ?? draft[keyPath: whole] },
            set: { value in
                if partDraft != nil {
                    partDraft?[keyPath: part] = value
                } else {
                    draft[keyPath: whole] = value
                }
            }
        )
    }

    private func run(_ operation: @escaping () async -> Bool) {
        Task {
            if await operation() { dismiss() }
        }
    }

    private var billDueDate: Binding<Date> {
        let day = field(\.billDueDate, \.billDueDate)
        return Binding(get: { day.wrappedValue.date() }, set: { day.wrappedValue = CalendarDay(date: $0) })
    }

    private var paidOn: Binding<Date> {
        let day = field(\.paidOn, \.paidOn)
        return Binding(get: { day.wrappedValue.date() }, set: { day.wrappedValue = CalendarDay(date: $0) })
    }
}
