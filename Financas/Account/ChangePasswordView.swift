import SwiftUI

struct ChangePasswordView: View {
    @Environment(AccountManager.self) private var account
    @Environment(\.dismiss) private var dismiss

    @State private var current = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var mismatch = false
    @State private var changed = false

    var body: some View {
        Form {
            if changed {
                Section {
                    Label("Senha alterada", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.positive)
                } footer: {
                    Text("Os outros aparelhos saíram da conta e vão pedir a senha nova.")
                }
            } else {
                Section {
                    SecureField("Senha atual", text: $current)
                        .textContentType(.password)
                } footer: {
                    Text("Esqueceu a senha atual? Saia da conta e use \"Esqueci minha senha\" na tela de entrada.")
                }

                Section {
                    SecureField("Nova senha", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Repita a nova senha", text: $confirmation)
                        .textContentType(.newPassword)
                } footer: {
                    Text("Mínimo de \(AccountConstants.minimumPasswordLength) caracteres. Os outros aparelhos vão sair da conta.")
                }

                if let message = mismatch ? "As senhas não conferem." : account.errorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(Theme.warning)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Alterar senha")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if changed {
                    Button("OK") { dismiss() }
                } else if account.isWorking {
                    ProgressView()
                } else {
                    Button("Salvar") {
                        Task { await save() }
                    }
                    .disabled(current.isEmpty || password.isEmpty || confirmation.isEmpty)
                }
            }
        }
        .onAppear { account.clearError() }
        .onDisappear { account.clearError() }
    }

    private func save() async {
        mismatch = password != confirmation
        guard !mismatch else { return }
        changed = await account.changePassword(current: current, new: password)
    }
}
