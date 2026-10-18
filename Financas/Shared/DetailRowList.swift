import SwiftUI

struct DetailRowList<Item: Identifiable, Row: View>: View where Item.ID == String {
    let items: [Item]
    let context: ListDetailContext
    let route: (Item) -> DetailRoute
    @ViewBuilder let row: (Item, Bool) -> Row

    var body: some View {
        let routes = items.map(route)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                let itemRoute = route(item)
                DetailRowLink(route: itemRoute, context: context) {
                    row(item, context.isSelected(itemRoute))
                }
                if item.id != items.last?.id {
                    Divider()
                        .opacity(context.hidesDivider(after: itemRoute, in: routes) ? 0 : 1)
                }
            }
        }
    }
}
