import SwiftUI

struct CardConnectionsView: View {
    var showsDone = false
    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var flow = PluggyConnectFlow()
    @State private var renaming: CardAccount?
    @State private var nicknameDraft = ""
    @State private var removing: CardConnection?
    @State private var opensIntro = false

    var body: some View {
        List {
            Section {
                Text(CardConstants.connectionsIntro)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4))

            if !store.snapshot.connections.isEmpty {
                Section {
                    ForEach(store.snapshot.connections) { connection in
                        CardConnectionRow(
                            connection: connection,
                            accounts: store.accounts.filter { $0.connectionID == connection.id },
                            onRename: beginRename,
                            onReconnect: { reconnect(connection) }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Remover", role: .destructive) {
                                removing = connection
                            }
                        }
                    }
                } footer: {
                    Text(CardConstants.connectionsSwipeHint)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }

            Section {
                GlassPrimaryButton(title: "＋ Conectar banco") {
                    opensIntro = true
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if let message = flow.failure ?? store.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Cartões conectados")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .navigationDestination(isPresented: $opensIntro) {
            ConnectBankIntroView()
        }
        .sheet(item: $flow.request) { request in
            PluggyConnectSheet(request: request) { event in
                Task { _ = await flow.handle(event, store: store) }
            }
        }
        .alert(CardConstants.nicknamePrompt, isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField(CardConstants.nicknamePrompt, text: $nicknameDraft)
            Button("Cancelar", role: .cancel) {}
            Button("Salvar") {
                if let account = renaming {
                    Task { await store.rename(account, to: nicknameDraft) }
                }
            }
        }
        .confirmationDialog(
            removing.map { "Remover \(store.nickname(for: $0))?" } ?? "",
            isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible,
            presenting: removing
        ) { connection in
            Button("Remover", role: .destructive) {
                Task { await store.remove(connection) }
            }
        } message: { _ in
            Text("Os dados desse cartão saem do app.")
        }
    }

    private func beginRename(_ account: CardAccount) {
        nicknameDraft = account.nickname
        renaming = account
    }

    private func reconnect(_ connection: CardConnection) {
        Task { await flow.begin(for: connection, store: store) }
    }
}
