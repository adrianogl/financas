import Foundation
import Testing
@testable import Financas

@MainActor
struct AppNavigationTests {
    @Test func openRouteSwitchesSection() {
        let nav = AppNavigation(defaults: UserDefaults(suiteName: #function)!)
        nav.open(.expense(id: "x", month: YearMonth(year: 2026, month: 10)))
        #expect(nav.section == .expenses)
        #expect(nav.takeSelection(for: .incomes) == nil)
        #expect(nav.takeSelection(for: .expenses) == .expense(id: "x", month: YearMonth(year: 2026, month: 10)))
        #expect(nav.takeSelection(for: .expenses) == nil)
    }

    @Test func sidebarStateIsRemembered() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        #expect(AppNavigation(defaults: defaults).isSidebarOpen)
        AppNavigation(defaults: defaults).isSidebarOpen = false
        #expect(!AppNavigation(defaults: defaults).isSidebarOpen)
    }

    @Test func portraitStartsCollapsedWithoutForgettingLandscape() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let nav = AppNavigation(defaults: defaults)
        #expect(nav.showsSidebar(in: .regularLandscape))
        #expect(!nav.showsSidebar(in: .regularPortrait))
        #expect(!nav.showsSidebar(in: .compact))

        nav.setSidebar(open: true, in: .regularPortrait)
        #expect(nav.showsSidebar(in: .regularPortrait))
        nav.enter(.regularLandscape)
        nav.enter(.regularPortrait)
        #expect(!nav.showsSidebar(in: .regularPortrait))

        nav.setSidebar(open: false, in: .regularPortrait)
        #expect(nav.showsSidebar(in: .regularLandscape))
        nav.setSidebar(open: false, in: .regularLandscape)
        #expect(!AppNavigation(defaults: defaults).showsSidebar(in: .regularLandscape))
    }

    @Test func visibilityFollowsCurrentMode() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let nav = AppNavigation(defaults: defaults)
        #expect(!nav.isSidebarVisible)
        nav.enter(.regularLandscape)
        #expect(nav.isSidebarVisible)
        nav.enter(.regularPortrait)
        #expect(!nav.isSidebarVisible)
        nav.enter(.compact)
        #expect(!nav.isSidebarVisible)
    }
}
