import SwiftUI

struct LockView: View {
    @Environment(LockManager.self) private var lockManager

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            AppLogo(markSize: 88)
                .padding(.bottom, 4)
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
        .readableWidth()
        .background(AppBackground())
        .onAppear { lockManager.autoUnlockIfNeeded() }
    }
}
