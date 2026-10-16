import SwiftUI

struct PINEntryView: View {
    @Environment(LockManager.self) private var lockManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = lockManager.lockoutRemaining(at: context.date)
            VStack(spacing: 24) {
                AppMark(size: 52)
                    .padding(.top, 32)

                PINPadView(
                    title: "Digite seu PIN",
                    message: message(lockoutRemaining: remaining),
                    isLocked: remaining != nil,
                    rejectionCount: lockManager.rejectedPINCount,
                    leadingAction: biometricAction,
                    onComplete: lockManager.submitPIN
                )

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .background(AppBackground())
    }

    private var biometricAction: PINPadAction? {
        let biometry = lockManager.biometry
        guard biometry != .none else { return nil }
        return PINPadAction(title: "Usar \(biometry.title)", systemImage: biometry.systemImage) {
            Task { await lockManager.unlock() }
        }
    }

    private func message(lockoutRemaining remaining: TimeInterval?) -> String? {
        guard let remaining else { return lockManager.pinMessage }
        let wait = Duration.seconds(Int(remaining.rounded(.up)))
            .formatted(.units(allowed: [.minutes, .seconds], width: .abbreviated))
        return "Muitas tentativas. Tente de novo em \(wait)."
    }
}
