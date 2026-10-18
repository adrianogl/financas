struct ListDetailState: Equatable {
    private(set) var selection: DetailRoute?
    private(set) var isSelectedByUser = false
    private(set) var isSheetPresented = false
    private var month: YearMonth?

    mutating func select(_ route: DetailRoute, presentation: DetailPresentation) {
        selection = route
        isSelectedByUser = true
        isSheetPresented = presentation == .sheet
    }

    mutating func applyDefault(routes: [DetailRoute], openRoutes: [DetailRoute], month: YearMonth, isLoaded: Bool = true, exists: (DetailRoute) -> Bool) {
        guard isLoaded else { return }
        let isSameMonth = month == self.month
        self.month = month
        if isSameMonth, isSelectedByUser, let selection, exists(selection) { return }
        let id = DetailSelection.resolve(
            current: selection?.occurrenceID,
            ids: routes.map(\.occurrenceID),
            openIDs: openRoutes.map(\.occurrenceID)
        )
        let resolved = routes.first { $0.occurrenceID == id }
        guard resolved != selection else { return }
        selection = resolved
        isSelectedByUser = false
    }

    mutating func presentationChanged(from old: DetailPresentation?, to new: DetailPresentation, isActive: Bool) {
        switch new {
        case .panel, .push:
            isSheetPresented = false
        case .sheet:
            if old == .panel, isActive, isSelectedByUser, selection != nil {
                isSheetPresented = true
            }
        }
    }

    mutating func dismissSheet() {
        guard isSheetPresented else { return }
        isSheetPresented = false
        isSelectedByUser = false
    }
}
