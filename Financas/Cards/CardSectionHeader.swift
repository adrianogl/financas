import SwiftUI

struct CardSectionHeader<Destination: View>: View {
    let title: String
    let linkTitle: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let linkTitle {
                NavigationLink(linkTitle, destination: destination)
                    .font(.subheadline)
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 6)
    }
}
