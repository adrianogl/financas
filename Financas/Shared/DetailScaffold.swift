import SwiftUI

struct DetailScaffold<Item, Content: View>: View {
    @Environment(\.isDetailPanel) private var isPanel
    let item: Item?
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        if isPanel {
            found
                .padding(DetailConstants.panelPadding)
        } else {
            ScrollView {
                found
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .readableWidth(LayoutConstants.contentWidth)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var found: some View {
        if let item {
            content(item)
        } else {
            Text("Não encontrada")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
        }
    }
}
