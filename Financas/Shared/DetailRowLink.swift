import SwiftUI

struct DetailRowLink<Label: View>: View {
    @Environment(AppNavigation.self) private var navigation
    let route: DetailRoute
    let context: ListDetailContext
    @ViewBuilder let label: () -> Label

    var body: some View {
        Group {
            if context.presentation == .push {
                NavigationLink(value: route, label: label)
            } else {
                Button(action: select, label: label)
            }
        }
        .buttonStyle(.plain)
    }

    private func select() {
        navigation.select(route, in: context.section, presentation: context.presentation)
    }
}
