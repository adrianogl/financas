import Testing
@testable import Financas

struct PluggyConnectEventTests {
    @Test func parsesSuccess() {
        #expect(PluggyConnectEvent.parse(["event": "success", "itemId": "abc"]) == .success(itemID: "abc"))
    }

    @Test func parsesCloseAndError() {
        #expect(PluggyConnectEvent.parse(["event": "close"]) == .close)
        #expect(PluggyConnectEvent.parse(["event": "error"]) == .error)
        #expect(PluggyConnectEvent.parse("lixo") == nil)
        #expect(PluggyConnectEvent.parse(["event": "outro"]) == nil)
    }

    @Test func successWithoutItemIDIsError() {
        #expect(PluggyConnectEvent.parse(["event": "success"]) == .error)
        #expect(PluggyConnectEvent.parse(["event": "success", "itemId": ""]) == .error)
    }
}
