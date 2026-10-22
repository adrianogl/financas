import Testing
@testable import Financas

struct CardPagingTests {
    @Test func fetchAllPagesUntilShortPage() async throws {
        var calls: [(Int, Int)] = []
        let rows = try await CardPaging.fetchAll(pageSize: 1000) { from, to in
            calls.append((from, to))
            return Array(repeating: 0, count: from == 2000 ? 37 : 1000)
        }
        #expect(rows.count == 2037)
        #expect(calls.map(\.0) == [0, 1000, 2000])
        #expect(calls.map(\.1) == [999, 1999, 2999])
    }

    @Test func fetchAllStopsAfterEmptyPage() async throws {
        var calls = 0
        let rows = try await CardPaging.fetchAll(pageSize: 10) { _, _ in
            calls += 1
            return calls == 1 ? Array(repeating: 0, count: 10) : []
        }
        #expect(rows.count == 10)
        #expect(calls == 2)
    }
}
