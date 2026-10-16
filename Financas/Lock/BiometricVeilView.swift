import SwiftUI

struct BiometricVeilView: View {
    let biometry: BiometryKind

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
                .frame(height: 60)
            Image(systemName: biometry.systemImage)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse)
            Text(biometry.prompt)
                .font(.headline)
            Text("Seus dados estão logo atrás desse vidro.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
