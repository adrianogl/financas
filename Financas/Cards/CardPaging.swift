enum CardPaging {
    static func fetchAll<T>(pageSize: Int, fetch: (Int, Int) async throws -> [T]) async rethrows -> [T] {
        var rows: [T] = []
        var from = 0
        while true {
            let page = try await fetch(from, from + pageSize - 1)
            rows.append(contentsOf: page)
            if page.count < pageSize { return rows }
            from += pageSize
        }
    }
}
