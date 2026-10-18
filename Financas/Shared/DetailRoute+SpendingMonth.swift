extension DetailRoute {
    init(_ spending: SpendingMonth) {
        self = .spending(id: spending.id, month: spending.month)
    }
}
