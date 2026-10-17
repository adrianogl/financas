import SwiftUI

struct IncomeFormView: View {
    @Environment(IncomeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: IncomeDraft
    private let initialDraft: IncomeDraft
    @State private var endsIncome = false
    @State private var endMonth: YearMonth
    @State private var confirmsDelete = false

    private let income: Income?

    init(draft: IncomeDraft, income: Income?, today: CalendarDay) {
        _draft = State(initialValue: draft)
        initialDraft = draft
        _endMonth = State(initialValue: max(today.yearMonth, draft.startMonth))
        self.income = income
    }

    var body: some View {
        NavigationStack {
            Form {
                if draft.isNew, store.settings.orderedEnabledKinds.count > 1 {
                    Picker("Tipo", selection: $draft.kind) {
                        ForEach(store.settings.orderedEnabledKinds, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    TextField("Nome", text: $draft.name)
                        .textInputAutocapitalization(.sentences)
                    TextField(amountTitle, value: $draft.amount, format: .currency(code: IncomeConstants.currencyCode))
                        .keyboardType(.decimalPad)
                    if draft.amountChanged, draft.kind != .oneOff {
                        MonthField(title: "Novo valor a partir de", month: $draft.amountValidFrom)
                    }
                }

                switch draft.kind {
                case .oneOff:
                    Section {
                        DatePicker("Data", selection: oneOffDate, displayedComponents: .date)
                    }
                case .fixed, .hourly:
                    recurringFields
                }

                if let message = (draft == initialDraft ? nil : draft.validationMessage) ?? store.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    .listRowBackground(Color.clear)
                }

                if let income {
                    manageSection(income)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(draft.isNew ? "Nova receita" : "Editar receita")
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
                            if await store.save(draft) { dismiss() }
                        }
                    }
                    .disabled(draft.validationMessage != nil || store.isSaving)
                }
            }
            .confirmationDialog("Excluir receita?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Excluir", role: .destructive) {
                    guard let income else { return }
                    Task {
                        if await store.delete(income) { dismiss() }
                    }
                }
            } message: {
                Text("Os recebimentos marcados desta receita também serão apagados.")
            }
        }
    }

    @ViewBuilder
    private var recurringFields: some View {
        Section {
            Picker("Dia do recebimento", selection: $draft.dayOfMonth) {
                ForEach(IncomeFormConstants.days, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            if draft.kind == .hourly {
                TextField("Horas por dia", value: $draft.hoursPerDay, format: .number.locale(IncomeFormat.locale))
                    .keyboardType(.decimalPad)
            }
        } footer: {
            Text(store.settings.nonBusinessDay.formHint(hourly: draft.kind == .hourly))
        }

        Section {
            MonthField(title: "Início", month: $draft.startMonth)
                .disabled(!draft.isNew)
            Toggle("Tem mês de fim", isOn: hasEnd)
            if let end = draft.endMonth {
                MonthField(title: "Fim", month: Binding(get: { end }, set: { draft.endMonth = $0 }))
            }
        }
    }

    private func manageSection(_ income: Income) -> some View {
        Section {
            if income.kind != .oneOff, income.endMonth == nil {
                if endsIncome {
                    MonthField(title: "Último mês", month: $endMonth)
                    Button("Confirmar encerramento") {
                        Task {
                            if await store.end(income, in: endMonth) { dismiss() }
                        }
                    }
                    .disabled(store.isSaving)
                } else {
                    Button("Encerrar receita") {
                        endsIncome = true
                    }
                }
            }
            Button("Excluir receita", role: .destructive) {
                confirmsDelete = true
            }
        }
    }

    private var amountTitle: String {
        switch draft.kind {
        case .fixed: "Valor mensal"
        case .hourly: "Valor da hora"
        case .oneOff: "Valor"
        }
    }

    private var oneOffDate: Binding<Date> {
        Binding(get: { draft.oneOffDate.date() }, set: { draft.oneOffDate = CalendarDay(date: $0) })
    }

    private var hasEnd: Binding<Bool> {
        Binding(
            get: { draft.endMonth != nil },
            set: { draft.endMonth = $0 ? max(draft.startMonth, store.today.yearMonth) : nil }
        )
    }
}
