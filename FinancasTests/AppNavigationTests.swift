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

    @Test func selectionIsKeptPerSection() {
        let nav = AppNavigation(defaults: UserDefaults(suiteName: #function)!)
        let october = YearMonth(year: 2026, month: 10)
        nav.select(.income(id: "a", month: october), in: .incomes, presentation: .panel)
        nav.select(.expense(id: "b", month: october), in: .overdue, presentation: .panel)
        #expect(nav.selection(for: .incomes) == .income(id: "a", month: october))
        #expect(nav.selection(for: .overdue) == .expense(id: "b", month: october))
        #expect(nav.selection(for: .expenses) == nil)
    }

    @Test func rotationOpensSheetOnlyInActiveSection() {
        let nav = AppNavigation(defaults: UserDefaults(suiteName: #function)!)
        let october = YearMonth(year: 2026, month: 10)
        nav.section = .incomes
        nav.select(.income(id: "a", month: october), in: .incomes, presentation: .panel)
        nav.select(.expense(id: "b", month: october), in: .expenses, presentation: .panel)
        nav.presentationChanged(from: .panel, to: .sheet, in: .incomes)
        nav.presentationChanged(from: .panel, to: .sheet, in: .expenses)
        #expect(nav.isSheetPresented(in: .incomes))
        #expect(!nav.isSheetPresented(in: .expenses))
        nav.dismissSheet(in: .incomes)
        #expect(!nav.isSheetPresented(in: .incomes))
    }

    @Test func defaultSelectionUsesScreenOrder() {
        let nav = AppNavigation(defaults: UserDefaults(suiteName: #function)!)
        let october = YearMonth(year: 2026, month: 10)
        let routes: [DetailRoute] = [.income(id: "a", month: october), .income(id: "b", month: october)]
        nav.applyDefaultSelection(routes: routes, openRoutes: [routes[1]], month: october, exists: { _ in true }, in: .incomes)
        #expect(nav.selection(for: .incomes) == routes[1])
    }

    @Test func resetReturnsHomeAndForgetsSelectionsButKeepsSidebar() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let nav = AppNavigation(defaults: defaults)
        let october = YearMonth(year: 2026, month: 10)
        nav.isSidebarOpen = false
        nav.select(.expense(id: "b", month: october), in: .expenses, presentation: .sheet)
        nav.open(.income(id: "a", month: october))
        nav.reset()
        #expect(nav.section == .home)
        #expect(nav.pendingSelection == nil)
        #expect(nav.selection(for: .expenses) == nil)
        #expect(!nav.isSheetPresented(in: .expenses))
        #expect(!nav.isSidebarOpen)
    }
}
