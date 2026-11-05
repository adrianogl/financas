import AppIntents
import SwiftUI

struct SuggestionSnippet: View {
    let content: SuggestionSnippetContent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(content.amount)
                    .font(.title.weight(.bold))
                Text(content.merchant)
                    .font(.subheadline)
                Text(content.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Lançar em")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if let suggested = content.suggested {
                    Button(intent: ConfirmSuggestionIntent(suggestionID: content.suggestionID, expenseID: suggested.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(suggested.name)
                                    .font(.body.weight(.semibold))
                                if let hint = suggested.hint {
                                    Text(hint)
                                        .font(.caption)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "checkmark")
                        }
                        .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .buttonStyle(.borderedProminent)
                }
                HStack(spacing: 8) {
                    ForEach(content.alternatives) { choice in
                        Button(intent: ConfirmSuggestionIntent(suggestionID: content.suggestionID, expenseID: choice.id)) {
                            Text(choice.name)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(intent: OpenSuggestionReviewIntent()) {
                        Text("Outro…")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button(intent: DismissSuggestionIntent(suggestionID: content.suggestionID)) {
                Text("Não é gasto do mês")
                    .font(.footnote)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
    }
}
