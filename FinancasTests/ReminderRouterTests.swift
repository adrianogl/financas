import Testing
@testable import Financas

@MainActor
struct ReminderRouterTests {
    @Test func routeWaitsForUnlock() {
        let router = ReminderRouter()
        router.receive(userInfo: ["route": "overdue"])
        #expect(router.take(isUnlocked: false) == nil)
        #expect(router.take(isUnlocked: true) == .overdue)
        #expect(router.take(isUnlocked: true) == nil)
    }

    @Test func ignoresUnknownRoute() {
        let router = ReminderRouter()
        router.receive(userInfo: ["route": "x"])
        #expect(router.pendingRoute == nil)
    }

    @Test func incomesRoute() {
        let router = ReminderRouter()
        router.receive(userInfo: ["route": "incomes"])
        #expect(router.take(isUnlocked: true) == .incomes)
    }
}
