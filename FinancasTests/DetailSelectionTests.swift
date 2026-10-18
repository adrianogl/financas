import Testing
@testable import Financas

struct DetailSelectionTests {
    @Test func picksFirstOpen() {
        #expect(DetailSelection.resolve(current: nil, ids: ["a", "b", "c"], openIDs: ["b", "c"]) == "b")
    }

    @Test func picksFirstWhenNothingOpen() {
        #expect(DetailSelection.resolve(current: nil, ids: ["a", "b"], openIDs: []) == "a")
    }

    @Test func emptyListSelectsNothing() {
        #expect(DetailSelection.resolve(current: "a", ids: [], openIDs: []) == nil)
    }

    @Test func keepsCurrentSelectionWhenStillPresent() {
        #expect(DetailSelection.resolve(current: "c", ids: ["a", "b", "c"], openIDs: ["a"]) == "c")
    }

    @Test func fallsBackWhenSelectionMissing() {
        #expect(DetailSelection.resolve(current: "old", ids: ["a", "b"], openIDs: ["b"]) == "b")
    }
}
