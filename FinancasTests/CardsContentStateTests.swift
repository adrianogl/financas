import Testing
@testable import Financas

struct CardsContentStateTests {
    @Test func spinnerOnlyWithoutData() {
        #expect(CardsContentState.make(loadState: .idle, hasData: false) == .spinner)
        #expect(CardsContentState.make(loadState: .loading, hasData: false) == .spinner)
    }

    @Test func keepsDashboardWhileReloading() {
        #expect(CardsContentState.make(loadState: .loading, hasData: true) == .dashboard(failure: nil))
        #expect(CardsContentState.make(loadState: .idle, hasData: true) == .dashboard(failure: nil))
    }

    @Test func failureWithoutDataShowsError() {
        #expect(CardsContentState.make(loadState: .failed("erro"), hasData: false) == .error("erro"))
    }

    @Test func failureWithDataKeepsDashboardWithInlineMessage() {
        #expect(CardsContentState.make(loadState: .failed("erro"), hasData: true) == .dashboard(failure: "erro"))
    }

    @Test func loadedWithoutConnectionsShowsEmptyState() {
        #expect(CardsContentState.make(loadState: .loaded, hasData: false) == .empty)
        #expect(CardsContentState.make(loadState: .loaded, hasData: true) == .dashboard(failure: nil))
    }
}
