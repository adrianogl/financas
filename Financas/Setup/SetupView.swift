import SwiftUI

struct SetupView: View {
    @Environment(LockManager.self) private var lockManager
    @AppStorage(ProfileConstants.nameKey) private var name = ""

    @State private var step: SetupStep = .name
    @State private var draftName = ""
    @State private var firstPIN = ""
    @State private var message: String?
    @State private var rejectionCount = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        Group {
            switch step {
            case .name:
                nameStep
            case .createPIN:
                PINPadView(
                    title: "Crie um PIN de \(LockConstants.pinLength) dígitos",
                    message: message ?? pinHint,
                    rejectionCount: rejectionCount
                ) { pin in
                    firstPIN = pin
                    message = nil
                    step = .confirmPIN
                }
                .padding(.top, 48)
            case .confirmPIN:
                PINPadView(title: "Repita o PIN", rejectionCount: rejectionCount, onComplete: confirm)
                    .padding(.top, 48)
            }
        }
        .id(step)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppBackground())
        .animation(.smooth, value: step)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppMark(size: 56)
            Text("Como você quer ser chamado?")
                .font(.largeTitle.bold())
            TextField("Seu nome", text: $draftName)
                .font(.title3)
                .textContentType(.givenName)
                .submitLabel(.continue)
                .focused($nameFocused)
                .onSubmit(continueFromName)
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
            Spacer()
            Button(action: continueFromName) {
                Text("Continuar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(trimmedName.isEmpty)
        }
        .padding(24)
        .padding(.top, 24)
        .onAppear { nameFocused = true }
    }

    private var pinHint: String {
        let biometry = lockManager.biometry
        guard biometry != .none else { return "É com ele que você vai abrir o app." }
        return "Ele entra no lugar do \(biometry.title) quando o \(biometry.title) falhar."
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func continueFromName() {
        guard !trimmedName.isEmpty else { return }
        name = trimmedName
        step = .createPIN
    }

    private func confirm(_ pin: String) {
        guard pin == firstPIN else {
            message = "Os PINs não conferem. Crie de novo."
            rejectionCount += 1
            step = .createPIN
            return
        }

        do {
            try lockManager.createPIN(pin)
        } catch {
            message = error.message
            step = .createPIN
        }
    }
}
