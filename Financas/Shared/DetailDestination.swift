import SwiftUI

struct DetailDestination: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: DetailRoute.self) { route in
            DetailRouteView(route: route)
                .background(AppBackground())
        }
    }
}

extension View {
    func detailDestination() -> some View {
        modifier(DetailDestination())
    }
}
