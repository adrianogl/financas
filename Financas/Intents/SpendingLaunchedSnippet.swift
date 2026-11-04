import AppIntents
import SwiftUI

struct SpendingLaunchedSnippet: View {
    let title: String
    let total: String
    let entryID: UUID

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.positive)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(total)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(intent: UndoSpendingEntryIntent(entryID: entryID)) {
                Text("Desfazer")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}
