import SwiftUI

struct RecurrenceReviewSheet: View {
    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var deciding: Set<String> = []

    var body: some View {
        let candidates = store.candidates

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cobranças parecidas em 3 meses ou mais. Só entram nos fixos as que você marcar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                    if let message = store.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                            .padding(.horizontal, 6)
                    }
                    CardListCard(items: candidates, emptyText: "Nenhuma recorrência para revisar.") { candidate in
                        row(candidate)
                    }
                }
                .padding(20)
                .readableWidth(LayoutConstants.contentWidth)
            }
            .background(AppBackground())
            .navigationTitle("Revisar recorrências")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: candidates.isEmpty) { _, isEmpty in
            if isEmpty { dismiss() }
        }
    }

    private func row(_ candidate: RecurrenceCandidate) -> some View {
        let isDeciding = deciding.contains(candidate.id)
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(store.nickname(for: candidate.cardAccountID)) · \(CardFormat.candidateText(monthCount: candidate.monthCount, amount: candidate.typicalAmount))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if candidate.chargedAfterEnd {
                    CardPill(text: "cobrado depois de encerrado", color: Theme.review)
                        .padding(.top, 2)
                }
            }
            HStack(spacing: 8) {
                Button("É fixo") {
                    decide(candidate, isFixed: true)
                }
                .buttonStyle(.glassProminent)
                Button("Não é fixo") {
                    decide(candidate, isFixed: false)
                }
                .buttonStyle(.glass)
            }
            .font(.subheadline.weight(.semibold))
            .controlSize(.small)
            .disabled(isDeciding)
        }
        .padding(.vertical, 10)
    }

    private func decide(_ candidate: RecurrenceCandidate, isFixed: Bool) {
        deciding.insert(candidate.id)
        Task {
            await store.decide(candidate, isFixed: isFixed)
            deciding.remove(candidate.id)
        }
    }
}
