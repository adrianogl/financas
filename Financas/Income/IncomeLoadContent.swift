import SwiftUI

struct IncomeLoadContent<Loaded: View>: View {
    @Environment(IncomeStore.self) private var store
    @ViewBuilder let loaded: () -> Loaded

    var body: some View {
        switch store.loadState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tentar de novo") {
                    Task { await store.load() }
                }
                .buttonStyle(.glass)
            }
            .frame(maxWidth: .infinity, minHeight: 160)
        case .loaded:
            loaded()
        }
    }
}
