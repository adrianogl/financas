struct ListDetailContext {
    let section: AppTab
    let presentation: DetailPresentation
    let selection: DetailRoute?

    func isSelected(_ route: DetailRoute) -> Bool {
        presentation == .panel && route == selection
    }

    func hidesDivider(after route: DetailRoute, in routes: [DetailRoute]) -> Bool {
        guard let index = routes.firstIndex(of: route) else { return false }
        let next = routes.index(after: index)
        return isSelected(route) || (next < routes.endIndex && isSelected(routes[next]))
    }
}
