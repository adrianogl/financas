import Testing
@testable import Financas

struct PluggyConnectPageTests {
    @Test func pageEmbedsTokenOnlyMeuPluggyAndWidgetVersion() {
        let html = PluggyConnectPage.html(token: "tok\"</script>", itemID: nil)
        #expect(html.contains("pluggy-connect/v2.9.2/pluggy-connect.js"))
        #expect(html.contains("connectorIds: [200]"))
        #expect(!html.contains("tok\"</script>"))
        #expect(!html.contains("updateItem"))
    }

    @Test func pageSendsUpdateItemOnReconnect() {
        let html = PluggyConnectPage.html(token: "t", itemID: "it1")
        #expect(html.contains("updateItem"))
        #expect(html.contains("it1"))
    }

    @Test func hostileItemIDStaysEscaped() {
        let html = PluggyConnectPage.html(token: "t", itemID: "x</script><script>alert(1)")
        #expect(!html.contains("x</script>"))
    }
}
