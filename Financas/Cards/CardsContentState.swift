enum CardsContentState: Equatable {
    case spinner
    case error(String)
    case empty
    case dashboard(failure: String?)

    static func make(loadState: IncomeLoadState, hasData: Bool) -> CardsContentState {
        switch loadState {
        case .idle, .loading:
            hasData ? .dashboard(failure: nil) : .spinner
        case .failed(let message):
            hasData ? .dashboard(failure: message) : .error(message)
        case .loaded:
            hasData ? .dashboard(failure: nil) : .empty
        }
    }
}
