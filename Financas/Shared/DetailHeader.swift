import SwiftUI

struct DetailHeader: View {
    let rule: String
    let title: String
    let edit: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(rule)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title.weight(.bold))
            }
            Spacer(minLength: 8)
            Button("Editar", action: edit)
                .buttonStyle(.glass)
        }
    }
}
