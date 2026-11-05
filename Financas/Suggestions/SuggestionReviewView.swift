import SwiftUI

struct SuggestionReviewView: View {
    @Environment(SuggestionStore.self) private var store
    @Environment(CardStore.self) private var cards
    @Environment(\.dismiss) private var dismiss
    @State private var tab: SuggestionReviewTab = .pending
    let today: CalendarDay

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Compras", selection: $tab) {
                        Text("Pendentes (\(store.pending.count))").tag(SuggestionReviewTab.pending)
                        Text("Ignoradas").tag(SuggestionReviewTab.dismissed)
                    }
                    .pickerStyle(.segmented)

                    if let message = store.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }

                    if items.isEmpty {
                        Text(emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    }

                    ForEach(days, id: \.self) { day in
                        Text(dayTitle(day))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.top, 4)
                        ForEach(items.filter { $0.spentOn == day }) { suggestion in
                            SuggestionReviewCard(suggestion: suggestion, today: today)
                        }
                    }
                }
                .padding(20)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .navigationTitle("Revisar compras")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") { dismiss() }
                }
                if tab == .pending && !store.pending.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Confirmar todas") {
                            Task { await confirmAll() }
                        }
                        .disabled(store.isSaving)
                    }
                }
            }
            .refreshable { await store.refresh() }
            .task { await store.refresh() }
        }
    }

    private var items: [SpendingSuggestion] {
        tab == .pending ? store.pending : store.dismissed
    }

    private var days: [CalendarDay] {
        Array(Set(items.map(\.spentOn))).sorted(by: >)
    }

    private var emptyMessage: String {
        tab == .pending
            ? "Nenhuma compra da Carteira para revisar. As compras com Apple Pay aparecem aqui quando a automação estiver ligada."
            : "Nenhuma compra ignorada nos últimos \(SuggestionConstants.historyDays) dias."
    }

    private func dayTitle(_ day: CalendarDay) -> String {
        if day == today { return "Hoje" }
        if day == today.adding(days: -1) { return "Ontem" }
        return day.date().formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private func confirmAll() async {
        for suggestion in store.pending where CardOverlap.installment(for: suggestion, in: cards.snapshot.transactions) == nil {
            let options = store.options(for: suggestion, today: today)
            guard let expense = store.suggestedExpense(for: suggestion, options: options) else { continue }
            _ = await store.confirm(suggestion, in: expense)
        }
    }
}
