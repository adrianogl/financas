enum IncomeLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}
