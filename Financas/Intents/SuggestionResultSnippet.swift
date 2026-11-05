import AppIntents
import SwiftUI

struct SuggestionResultSnippet: View {
    let tone: SuggestionResultTone
    let title: String
    let detail: String
    let action: SuggestionResultAction?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            switch action {
            case .undo(let suggestionID):
                Button(intent: UndoSuggestionIntent(suggestionID: suggestionID)) {
                    Text("Desfazer")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.bordered)
            case .move(let suggestionID, let expenseID, _):
                Button(intent: MoveSuggestionIntent(suggestionID: suggestionID, expenseID: expenseID)) {
                    Text("Mover")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
            case nil:
                EmptyView()
            }
        }
        .padding()
    }

    private var symbol: String {
        switch tone {
        case .done: "checkmark.circle.fill"
        case .info: "square.on.square"
        case .attention: "exclamationmark.circle.fill"
        }
    }

    private var tint: Color {
        switch tone {
        case .done: Theme.positive
        case .info: .secondary
        case .attention: Theme.review
        }
    }
}
