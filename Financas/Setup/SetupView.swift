import SwiftUI

struct SetupView: View {
    @Environment(LockManager.self) private var lockManager

    @State private var step: SetupStep = .createPIN
    @State private var firstPIN = ""
    @State private var message: String?
    @State private var rejectionCount = 0

    var body: some View {
        Group {
            switch step {
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
            case .confirmPIN:
                PINPadView(title: "Repita o PIN", rejectionCount: rejectionCount, onComplete: confirm)
            }
        }
        .padding(.top, 48)
        .id(step)
        .readableWidth()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppBackground())
        .animation(.smooth, value: step)
    }

    private var pinHint: String {
        let biometry = lockManager.biometry
        guard biometry != .none else { return "É com ele que você vai abrir o app neste aparelho." }
        return "Ele entra no lugar do \(biometry.title) quando o \(biometry.title) falhar."
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
