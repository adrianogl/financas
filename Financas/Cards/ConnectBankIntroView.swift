import SwiftUI

struct ConnectBankIntroView: View {
    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var request: PluggyConnectRequest?
    @State private var isWorking = false
    @State private var failure: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(CardConstants.connectIntroTitle)
                        .font(.headline)
                    ForEach(Array(CardConstants.connectIntroSteps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1).")
                                .monospacedDigit()
                            Text(step)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .glassEffect(.regular, in: .rect(cornerRadius: CardConstants.cardCornerRadius))

                Button {
                    if let url = URL(string: CardConstants.meuPluggyURL) {
                        openURL(url)
                    }
                } label: {
                    Text("Criar conta no MeuPluggy ↗")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                GlassPrimaryButton(title: "Continuar", isWorking: isWorking, action: proceed)

                if let message = failure ?? store.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .padding(.horizontal, 6)
                }
            }
            .padding(20)
            .readableWidth(LayoutConstants.contentWidth)
        }
        .background(AppBackground())
        .navigationTitle("Conectar banco")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $request) { request in
            PluggyConnectSheet(request: request, onEvent: handle)
        }
    }

    private func proceed() {
        failure = nil
        isWorking = true
        Task {
            let token = await store.connectToken(for: nil)
            isWorking = false
            guard let token else { return }
            request = PluggyConnectRequest(token: token, itemID: nil)
        }
    }

    private func handle(_ event: PluggyConnectEvent) {
        switch event {
        case .success(let itemID):
            Task {
                if await store.register(itemID: itemID) {
                    dismiss()
                }
            }
        case .error:
            failure = CardConstants.connectFailedMessage
        case .close:
            break
        }
    }
}
