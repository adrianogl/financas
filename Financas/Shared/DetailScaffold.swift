import SwiftUI

struct DetailScaffold<Item, Content: View>: View {
    @Environment(\.isDetailPanel) private var isPanel
    @Environment(\.dismiss) private var dismiss
    let item: Item?
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        layout
            .onChange(of: item != nil) { wasFound, isFound in
                if wasFound, !isFound, !isPanel {
                    dismiss()
                }
            }
    }

    @ViewBuilder
    private var layout: some View {
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
