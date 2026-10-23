import SwiftUI

struct CardsEmptyState: View {
    let onConnect: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "creditcard")
                .font(.largeTitle)
                .foregroundStyle(Theme.accent)
            Text("Nenhum cartão conectado")
                .font(.headline)
                .padding(.top, 4)
            Text("Conecte seus cartões para ver quanto já está comprometido com parcelas e assinaturas.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            GlassPrimaryButton(title: "Conectar banco", action: onConnect)
                .padding(.top, 10)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: CardConstants.cardCornerRadius))
    }
}
