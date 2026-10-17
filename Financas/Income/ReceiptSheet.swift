import SwiftUI

struct ReceiptSheet: View {
    @Environment(IncomeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ReceiptDraft

    let occurrence: IncomeOccurrence
    let editIncome: (Income) -> Void

    init(occurrence: IncomeOccurrence, today: CalendarDay, editIncome: @escaping (Income) -> Void) {
        self.occurrence = occurrence
        self.editIncome = editIncome
        _draft = State(initialValue: ReceiptDraft(occurrence: occurrence, today: today))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    header
                }
                .listRowBackground(Color.clear)

                if draft.hourlyRate != nil {
                    Section {
                        Stepper(value: workedDays, in: 0...31) {
                            LabeledContent("Dias trabalhados", value: "\(draft.workedDays ?? 0)")
                        }
                        LabeledContent("Horas") {
                            TextField("Horas", value: workedHours, format: .number.locale(IncomeFormat.locale))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Theme.accent)
                        }
                        LabeledContent("Valor da hora", value: IncomeFormat.currency(draft.hourlyRate ?? 0))
                    } footer: {
                        Text("Mude as horas se teve folga, férias ou hora extra.")
                    }
                }

                Section {
                    DatePicker("Recebido em", selection: receivedOn, displayedComponents: .date)
                    LabeledContent("Valor recebido") {
                        TextField("Valor recebido", value: $draft.amount, format: .currency(code: IncomeConstants.currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.accent)
                    }
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
                    GlassPrimaryButton(title: isReceived ? "Salvar" : "Marcar como recebida", isWorking: store.isSaving, action: save)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if isReceived || occurrence.income.kind == .oneOff {
                    Section {
                        if isReceived {
                            Button("Desmarcar recebimento", role: .destructive) {
                                Task {
                                    if await store.unmarkReceived(occurrence) { dismiss() }
                                }
                            }
                        }
                        if occurrence.income.kind == .oneOff {
                            Button("Editar receita") {
                                dismiss()
                                editIncome(occurrence.income)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(isReceived ? "Recebimento" : "Marcar recebida")
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
            Text(IncomeFormat.occurrenceTitle(occurrence))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(IncomeFormat.currency(draft.expectedAmount))
                .font(.system(size: 32, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("previsto para \(IncomeFormat.shortDate(occurrence.dueDate))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .animation(.smooth, value: draft.expectedAmount)
    }

    private var isReceived: Bool {
        occurrence.receipt != nil
    }

    private func save() {
        Task {
            if await store.markReceived(occurrence, with: draft) { dismiss() }
        }
    }

    private var workedDays: Binding<Int> {
        Binding(get: { draft.workedDays ?? 0 }, set: { draft.setWorkedDays($0) })
    }

    private var workedHours: Binding<Decimal> {
        Binding(get: { draft.workedHours ?? 0 }, set: { draft.setWorkedHours($0) })
    }

    private var receivedOn: Binding<Date> {
        Binding(get: { draft.receivedOn.date() }, set: { draft.receivedOn = CalendarDay(date: $0) })
    }
}
