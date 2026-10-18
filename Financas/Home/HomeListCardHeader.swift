import SwiftUI

struct HomeListCardHeader: View {
    let title: String
    let addLabel: String
    let add: () -> Void

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer(minLength: 8)
            HomePillButton(title: "+ Nova", tint: Theme.accent, action: add)
                .accessibilityLabel(addLabel)
        }
        .padding(.bottom, 6)
    }
}
