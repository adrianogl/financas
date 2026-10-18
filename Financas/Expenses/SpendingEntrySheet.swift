import SwiftUI

struct SpendingEntrySheet: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ExpenseEntryDraft
    private let initialDraft: ExpenseEntryDraft
    private let entry: ExpenseEntry?

    init(draft: ExpenseEntryDraft, entry: ExpenseEntry?) {
        _draft = State(initialValue: draft)
        initialDraft = draft
        self.entry = entry
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Valor") {
                        TextField("Valor", value: $draft.amount, format: .currency(code: IncomeConstants.currencyCode))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(Theme.accent)
                    }
                    DatePicker("Data", selection: spentOn, in: dateRange, displayedComponents: .date)
                }

                if let message = (draft == initialDraft ? nil : draft.validationMessage) ?? store.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    GlassPrimaryButton(title: draft.isNew ? "Adicionar" : "Salvar", isWorking: store.isSaving, action: save)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if let entry {
                    Section {
                        Button("Apagar gasto", role: .destructive) {
                            delete(entry)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(draft.isNew ? "Adicionar gasto" : "Editar gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(draft.isNew ? "Adicionar" : "Salvar", systemImage: "checkmark", action: save)
                        .disabled(store.isSaving)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var dateRange: ClosedRange<Date> {
        draft.validRange.lowerBound.date()...draft.validRange.upperBound.date()
    }

    private var spentOn: Binding<Date> {
        Binding(get: { draft.spentOn.date() }, set: { draft.spentOn = CalendarDay(date: $0) })
    }

    private func save() {
        Task {
            if await store.saveEntry(draft) { dismiss() }
        }
    }

    private func delete(_ entry: ExpenseEntry) {
        Task {
            if await store.deleteEntry(entry) { dismiss() }
        }
    }
}
