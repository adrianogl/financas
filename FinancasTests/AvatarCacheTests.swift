import Foundation
import Testing
@testable import Financas

struct AvatarCacheTests {
    @Test func roundTrips() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "avatar-\(UUID().uuidString)")
        let cache = AvatarCache(directory: directory)
        #expect(cache.load() == nil)

        cache.save(Data([1, 2, 3]), version: 9)
        let loaded = try #require(cache.load())
        #expect(loaded.version == 9)
        #expect(loaded.data == Data([1, 2, 3]))

        cache.clear()
        #expect(cache.load() == nil)
    }
}
