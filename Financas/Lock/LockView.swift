import SwiftUI

struct LockView: View {
    @Environment(LockManager.self) private var lockManager

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            AppMark(size: 88)
                .padding(.bottom, 8)
            Text("Finanças")
                .font(.title.bold())
            Text("Bloqueado")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let errorMessage = lockManager.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }

            Spacer()

            Button {
                Task { await lockManager.unlock() }
            } label: {
                Label("Desbloquear", systemImage: lockManager.biometry.systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(32)
        .background(AppBackground())
        .onAppear { lockManager.autoUnlockIfNeeded() }
    }
}
